import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../utils/config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import 'trainer_dashboard_page.dart';

import 'create_course_page.dart';
import 'edit_course_page.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/toast_helper.dart';
import 'trainer_profile_page.dart';
import '../../widgets/trainer/trainer_sidebar.dart';

class TrainerCoursesPage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerCoursesPage({super.key, this.isEmbedded = false});

  @override
  State<TrainerCoursesPage> createState() => _TrainerCoursesPageState();
}

class _TrainerCoursesPageState extends State<TrainerCoursesPage> {
  final _authService = AuthService();
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';
  bool _isLoading = true;
  String _errorMessage = '';

  // Tab Status Filters
  String _selectedStatus =
      'ALL'; // 'ALL', 'DRAFT', 'PUBLISHED', 'HIDDEN', 'PENDING'

  // Status Counts
  int _allCount = 0;
  int _draftCount = 0;
  int _publishedCount = 0;
  int _hiddenCount = 0;
  int _pendingCount = 0;

  // Filter values
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortBy = 'NEWEST'; // 'NEWEST', 'OLDEST', 'ALPHABETICAL'
  String _selectedTimePeriod = 'ALL'; // 'ALL', 'THIS_WEEK', 'THIS_MONTH'

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  // Courses List
  List<dynamic> _coursesList = [];
  bool _isDownloadingTemplate = false;
  bool _isImportingExcel = false;

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchCoursesData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _fetchCoursesData() async {
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

      final searchVal = _searchController.text.trim();
      final queryParams = <String, String>{
        'status': _selectedStatus,
        'sortBy': _selectedSortBy,
        'timePeriod': _selectedTimePeriod,
      };
      if (searchVal.isNotEmpty) {
        queryParams['search'] = searchVal;
      }

      final uri = Uri.parse(
        '$apiBaseUrl/trainer/courses',
      ).replace(queryParameters: queryParams);
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
          _allCount = (data['allCount'] ?? 0) as int;
          _draftCount = (data['draftCount'] ?? 0) as int;
          _publishedCount = (data['publishedCount'] ?? 0) as int;
          _hiddenCount = (data['hiddenCount'] ?? 0) as int;
          _pendingCount = (data['pendingCount'] ?? 0) as int;
          _coursesList = data['courses'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load courses data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading courses data: $e');
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
      _coursesList = [
        {
          'id': 1,
          'title': 'Grammar 8+',
          'status': 'PUBLISHED',
          'description':
              'Advanced grammar concepts tailored for high-achieving students....',
          'learnersCount': 0,
          'lessonsCount': 1,
          'thumbnailUrl': null,
          'createdAt': '2026-06-03T00:00:00',
        },
      ];
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

  Future<void> _deleteCourse(dynamic course) async {
    final title = course['title'] ?? 'Untitled Course';
    final courseId = course['id'] is int
        ? course['id'] as int
        : int.parse(course['id'].toString());

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Course',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/trainer/courses/$courseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ToastHelper.showSuccess(context, 'Course deleted successfully');
          _fetchCoursesData();
        }
      } else {
        throw Exception('Failed to delete course: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting course: $e');
      if (mounted) {
        ToastHelper.showError(context, 'Error deleting course: $e');
      }
    }
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
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
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

      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$apiBaseUrl/trainer/courses/import'),
            )
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

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        final importedCourses = data['importedCourses'] ?? 0;
        final importedSections = data['importedSections'] ?? 0;
        final importedLessons = data['importedLessons'] ?? 0;
        final warnings = data['warnings'];

        // CourseImportResultDTO: courseIds: List<Long>
        final dynamic courseIdsRaw = data['courseIds'];
        final List<int> courseIds = (courseIdsRaw is List)
            ? courseIdsRaw
                  .map((e) => e is int ? e : int.tryParse(e.toString()) ?? -1)
                  .where((id) => id > 0)
                  .toList()
            : [];

        if (mounted) {
          setState(() {
            _selectedStatus = 'ALL';
          });
          await _fetchCoursesData();

          final warningText = warnings is List && warnings.isNotEmpty
              ? ' Warning: ${warnings.first}'
              : '';

          if (mounted) {
            ToastHelper.showSuccess(
              context,
              'Imported $importedCourses course, $importedSections sections, $importedLessons lessons.$warningText',
            );
          }

          if (courseIds.isNotEmpty) {
            // Navigate to edit page for the first imported course
            final firstCourseId = courseIds.first;
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditCoursePage(courseId: firstCourseId),
                ),
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
    } catch (_) {
      // Fall back to the raw response below.
    }
    return responseBody.isEmpty ? 'Import failed' : responseBody;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Updated June 3, 2026';
    try {
      final dateTime = DateTime.parse(dateStr.toString());
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final month = months[dateTime.month - 1];
      return 'Updated $month ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return 'Updated June 3, 2026';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    if (widget.isEmbedded) {
      return _buildBodyContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      drawer: !isDesktop ? const Drawer(child: TrainerSidebar(activeIndex: 1)) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 260, child: TrainerSidebar(activeIndex: 1)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: _buildBodyContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    final paginatedGroups = _paginatedGroups;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
          sliver: SliverToBoxAdapter(child: _buildWelcomeSection()),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(child: _buildFilterContainer()),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Notice: $_errorMessage. Fallback data shown.',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48.0),
                      child: CircularProgressIndicator(color: Color(0xFF20B486)),
                    ),
                  )
                else if (_groupedCourses.isEmpty)
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
                        Icon(Icons.folder_open, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 16),
                        Text(
                          'No courses found matching this criteria',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!_isLoading && paginatedGroups.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _CourseCardWrapper(
                  group: paginatedGroups[index],
                  buildCard: _buildCourseCard,
                ),
                childCount: paginatedGroups.length,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(child: _buildPagination()),
        ),
      ],
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
          // Breadcrumb
          Row(
            children: const [
              Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
              SizedBox(width: 4),
              Text(
                'Courses',
                style: TextStyle(
                  color: Color(0xFF20B486),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const Spacer(),
          // Actions
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
          // User profile widget with Popup Menu
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'dashboard') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerDashboardPage(),
                  ),
                );
              } else if (val == 'profile') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerProfilePage(),
                  ),
                );
              } else if (val == 'logout') {
                _handleLogout();
              }
            },
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: const [
                    Icon(Icons.dashboard_outlined, size: 18, color: Color(0xFF20B486)),
                    SizedBox(width: 10),
                    Text(
                      'Dashboard',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: const [
                    Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 10),
                    Text(
                      'My Profile',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(fontFamily: 'Outfit', color: Colors.redAccent, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
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
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                    _trainerInitials,
                                    style: const TextStyle(
                                      color: Color(0xFF20B486),
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
                              color: Color(0xFF20B486),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _isDownloadingTemplate ? null : _downloadImportTemplate,
          icon: _isDownloadingTemplate
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF20B486),
                  ),
                )
              : const Icon(
                  Icons.download_outlined,
                  color: Color(0xFF20B486),
                  size: 18,
                ),
          label: const Text(
            'Download Template',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF20B486),
            side: const BorderSide(color: Color(0xFF20B486)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _isImportingExcel ? null : _importCourseExcel,
          icon: _isImportingExcel
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF20B486),
                  ),
                )
              : const Icon(
                  Icons.upload_file_outlined,
                  color: Color(0xFF20B486),
                  size: 18,
                ),
          label: const Text(
            'Import Excel',
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF20B486),
            side: const BorderSide(color: Color(0xFF99F6E4)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateCoursePage()),
            ).then((_) => _fetchCoursesData());
          },
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: const Text(
            'Create New Course',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth > 820;
        const title = Text(
          'Course Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            fontFamily: 'Outfit',
          ),
        );

        if (useRow) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              Flexible(child: actions),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 16), actions],
        );
      },
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
          // 1. Tabs row
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
                _buildStatusTab('Pending', 'PENDING', _pendingCount),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 2. Filters controls row
          LayoutBuilder(
            builder: (context, constraints) {
              final useRow = constraints.maxWidth > 768;

              final searchField = TextField(
                controller: _searchController,
                onChanged: (val) => _fetchCoursesData(),
                decoration: InputDecoration(
                  hintText: 'Search for courses...',
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
                    _fetchCoursesData();
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
                    _fetchCoursesData();
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
        _fetchCoursesData();
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

  // ─── Version grouping helpers ─────────────────────────────────────────────

  /// Resolves a flat list of versions (same `code`) into a typed group.
  ({dynamic published, dynamic draft, dynamic pending, List<dynamic> all})
  _resolveGroup(List<dynamic> group) {
    dynamic published;
    dynamic draft;
    dynamic pending;

    for (final c in group) {
      final s = (c['status'] ?? '').toString().toUpperCase();
      final id = (c['id'] ?? 0) as int;
      if (s == 'PUBLISHED' || s == 'HIDDEN' || s == 'ARCHIVED') {
        if (published == null || id > (published['id'] as int)) published = c;
      } else if (s == 'PENDING_APPROVAL' || s == 'PENDING' || s == 'SUBMITTED') {
        if (pending == null || id > (pending['id'] as int)) pending = c;
      } else {
        if (draft == null || id > (draft['id'] as int)) draft = c;
      }
    }
    return (published: published, draft: draft, pending: pending, all: group);
  }

  /// Groups _coursesList by `parentId` (if exists) or `id`, falling back to `code` if necessary.
  List<({dynamic published, dynamic draft, dynamic pending, List<dynamic> all})>
  get _groupedCourses {
    final Map<String, List<dynamic>> byKey = {};
    for (final c in _coursesList) {
      final code = (c['code'] ?? '').toString();
      // Code is like COURSE-1234 or COURSE-1234-V2. We group by the base code.
      final baseCode = code.contains('-V') ? code.split('-V')[0] : code;

      byKey.putIfAbsent(baseCode, () => []).add(c);
    }
    return byKey.values.map(_resolveGroup).toList();
  }

  int get _totalPages {
    final groups = _groupedCourses;
    if (groups.isEmpty) return 1;
    return (groups.length / _itemsPerPage).ceil();
  }

  List<({dynamic published, dynamic draft, dynamic pending, List<dynamic> all})> get _paginatedGroups {
    final groups = _groupedCourses;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= groups.length) return [];
    final endIndex = startIndex + _itemsPerPage;
    return groups.sublist(startIndex, endIndex > groups.length ? groups.length : endIndex);
  }

  /// Returns the lifecycle state string for a group.
  /// One of: 'LIVE_ONLY' | 'HAS_DRAFT' | 'DRAFT_ONLY' | 'PENDING'
  String _lifecycleState({
    required dynamic published,
    required dynamic draft,
    required dynamic pending,
    required List<dynamic> all,
  }) {
    if (pending != null) return 'PENDING';
    if (draft != null && published != null) return 'HAS_DRAFT';
    if (draft != null && published == null) return 'DRAFT_ONLY';
    return 'LIVE_ONLY';
  }

  // ─── Courses section ──────────────────────────────────────────────────────

  // ─── Course Card (lifecycle-aware) ────────────────────────────────────────

  Widget _buildCourseCard(
    ({dynamic published, dynamic draft, dynamic pending, List<dynamic> all}) group,
    bool isHovered,
  ) {
    final published = group.published;
    final draft = group.draft;
    final pending = group.pending;

    // Representative record: prefer published, then draft, then pending
    final course = published ?? draft ?? pending ?? group.all.first;

    final title = (course['title'] ?? 'Untitled Course') as String;
    final desc =
        (course['description'] ?? 'No description provided.') as String;
    final learners = course['learnersCount'] ?? 0;
    final lessons = course['lessonsCount'] ?? 0;
    final dateStr = _formatDate(course['createdAt']);
    final thumbnail = (course['thumbnailUrl'] ?? '') as String;

    final state = _lifecycleState(
      published: published,
      draft: draft,
      pending: pending,
      all: group.all,
    );

    int extractId(dynamic c) =>
        c['id'] is int ? c['id'] as int : int.parse(c['id'].toString());

    // Version label strings
    final pubVer = (published?['version'] ?? '').toString();
    final draftVer = (draft?['version'] ?? '').toString();
    final pendingVer = (pending?['version'] ?? '').toString();

    // State 4 – learner counts per published version

    // Border accent by state
    final borderColor = state == 'HAS_DRAFT'
        ? const Color(0xFFFDE68A)
        : state == 'PENDING'
        ? const Color(0xFFBFDBFE)
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
          width: 1.5
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
          // ── Body ─────────────────────────────────────────────────────────
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
                            Icons.school,
                            color: Color(0xFF20B486),
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.school,
                          color: Color(0xFF20B486),
                          size: 32,
                        ),
                );

                final infoCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + lifecycle badges
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
                        if (state == 'LIVE_ONLY')
                          _badge(
                            label: published != null
                                ? 'PUBLISHED${pubVer.isNotEmpty ? ' · $pubVer' : ''}'
                                : 'DRAFT${draftVer.isNotEmpty ? ' · $draftVer' : ''}',
                            bg: published != null
                                ? const Color(0xFFE6FFFA)
                                : const Color(0xFFF1F5F9),
                            fg: published != null
                                ? const Color(0xFF0D9373)
                                : const Color(0xFF64748B),
                          ),
                        if (state == 'HAS_DRAFT') ...[
                          _badge(
                            label:
                                '🟢 PUBLISHED${pubVer.isNotEmpty ? ' · $pubVer' : ''}',
                            bg: const Color(0xFFE6FFFA),
                            fg: const Color(0xFF0D9373),
                          ),
                          _badge(
                            label:
                                '🟡 Draft${draftVer.isNotEmpty ? ' $draftVer' : ''} Waiting Approval',
                            bg: const Color(0xFFFEF9C3),
                            fg: const Color(0xFF92400E),
                            border: const Color(0xFFFDE68A),
                          ),
                        ],
                        if (state == 'PENDING') ...[
                          _badge(
                            label:
                                '🟢 PUBLISHED${pubVer.isNotEmpty ? ' · $pubVer' : ''}',
                            bg: const Color(0xFFE6FFFA),
                            fg: const Color(0xFF0D9373),
                          ),
                          _badge(
                            label:
                                '🔵 Draft${pendingVer.isNotEmpty ? ' $pendingVer' : ''} Approved',
                            bg: const Color(0xFFEFF6FF),
                            fg: const Color(0xFF1D4ED8),
                            border: const Color(0xFFBFDBFE),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Stats
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _statChip(Icons.people_outline, '$learners learners'),
                        _statChip(Icons.class_outlined, '$lessons lessons'),
                        _statChip(Icons.calendar_today_outlined, dateStr),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontFamily: 'Outfit',
                        height: 1.4,
                      ),
                    ),
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

          // ── Lifecycle Action Bar ──────────────────────────────────────────
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
            child: _buildLifecycleActions(
              state: state,
              course: course,
              published: published,
              draft: draft,
              extractId: extractId,
              title: title,
              allVersions: group.all,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Per-state action bar ─────────────────────────────────────────────────

  Widget _buildLifecycleActions({
    required String state,
    required dynamic course,
    required dynamic published,
    required dynamic draft,
    required int Function(dynamic) extractId,
    required String title,
    required List<dynamic> allVersions,
  }) {
    switch (state) {
      // ── State 1: Normal – course is live ─────────────────────────────────
      case 'LIVE_ONLY':
        return Row(
          children: [
            _actionChip(
              icon: Icons.visibility_outlined,
              label: 'View',
              onTap: () => ToastHelper.show(
                context,
                'View course feature is under development',
              ),
            ),
            const SizedBox(width: 8),
            _actionChip(
              icon: Icons.edit_outlined,
              label: 'Edit / Create New Version',
              color: const Color(0xFF20B486),
              bg: const Color(0xFFE6F7F1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditCoursePage(courseId: extractId(course)),
                  ),
                ).then((_) => _fetchCoursesData());
              },
            ),
            const Spacer(),
            _iconBtn(
              icon: Icons.history,
              tooltip: 'Version history',
              color: const Color(0xFF64748B),
              onTap: () =>
                  _showVersionHistoryModal(context, title, allVersions),
            ),
          ],
        );

      // ── State 2: Trainer editing in progress ─────────────────────────────
      case 'HAS_DRAFT':
        return Row(
          children: [
            _actionChip(
              icon: Icons.edit_note,
              label: 'Continue Editing v2',
              color: const Color(0xFFD97706),
              bg: const Color(0xFFFEF3C7),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditCoursePage(courseId: extractId(draft)),
                  ),
                ).then((_) => _fetchCoursesData());
              },
            ),
            const SizedBox(width: 8),
            _actionChip(
              icon: Icons.history,
              label: 'Version History',
              color: const Color(0xFF475569),
              bg: const Color(0xFFF1F5F9),
              onTap: () =>
                  _showVersionHistoryModal(context, title, allVersions),
            ),
            const Spacer(),
            _actionChip(
              icon: Icons.cancel_outlined,
              label: 'Cancel Draft',
              color: const Color(0xFFEF4444),
              bg: const Color(0xFFFEE2E2),
              onTap: () => _deleteCourse(draft),
            ),
          ],
        );

      // ── State 4: Draft Only (or Rejected) ─────────────────────────────
      case 'DRAFT_ONLY':
        final s = (course['status'] ?? '').toString().toUpperCase();
        final isRejected = s == 'REJECTED';
        return Row(
          children: [
            _actionChip(
              icon: Icons.edit_outlined,
              label: isRejected ? 'Edit Rejected Course' : 'Edit Draft',
              color: isRejected ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
              bg: isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditCoursePage(courseId: extractId(course)),
                  ),
                ).then((_) => _fetchCoursesData());
              },
            ),
            const SizedBox(width: 8),
            _actionChip(
              icon: Icons.history,
              label: 'Version History',
              color: const Color(0xFF475569),
              bg: const Color(0xFFF1F5F9),
              onTap: () =>
                  _showVersionHistoryModal(context, title, allVersions),
            ),
            const Spacer(),
            _iconBtn(
              icon: Icons.delete_outline,
              tooltip: 'Delete course',
              color: const Color(0xFFEF4444),
              onTap: () => _deleteCourse(course),
            ),
          ],
        );

      // ── State 3: Waiting for Course Manager approval ──────────────────────
      case 'PENDING':
        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.hourglass_top, size: 15, color: Color(0xFF3B82F6)),
                  SizedBox(width: 6),
                  Text(
                    'Waiting for Course Manager approval...',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _iconBtn(
              icon: Icons.history,
              tooltip: 'Version history',
              color: const Color(0xFF3B82F6),
              onTap: () =>
                  _showVersionHistoryModal(context, title, allVersions),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _showVersionHistoryModal(
    BuildContext context,
    String courseTitle,
    List<dynamic> versions,
  ) {
    final sortedVersions = List<dynamic>.from(versions)
      ..sort((a, b) {
        final idA = (a['id'] ?? 0) as int;
        final idB = (b['id'] ?? 0) as int;
        return idB.compareTo(idA);
      });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 600,
          constraints: const BoxConstraints(maxHeight: 700),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course version history',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            courseTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
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
              // Body list
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  shrinkWrap: true,
                  itemCount: sortedVersions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = sortedVersions[index];
                    final version = (item['version'] ?? 'v1').toString();
                    final status = (item['status'] ?? 'DRAFT')
                        .toString()
                        .toUpperCase();
                    final dateStr = _formatDate(item['createdAt']);
                    final learners = item['learnersCount'] ?? 0;
                    final lessons = item['lessonsCount'] ?? 0;

                    Color statusBg;
                    Color statusFg;
                    String statusText;

                    if (status == 'PUBLISHED') {
                      statusBg = const Color(0xFFE6FFFA);
                      statusFg = const Color(0xFF0D9373);
                      statusText = 'Published';
                    } else if (status == 'PENDING_APPROVAL' ||
                        status == 'PENDING') {
                      statusBg = const Color(0xFFEFF6FF);
                      statusFg = const Color(0xFF1D4ED8);
                      statusText = 'Pending';
                    } else if (status == 'REJECTED') {
                      statusBg = const Color(0xFFFEF2F2);
                      statusFg = const Color(0xFFDC2626);
                      statusText = 'Rejected';
                    } else {
                      statusBg = const Color(0xFFFEF9C3);
                      statusFg = const Color(0xFF92400E);
                      statusText = 'Draft';
                    }

                    int extractId(dynamic c) => c['id'] is int
                        ? c['id'] as int
                        : int.parse(c['id'].toString());
                    final courseId = extractId(item);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              version.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusFg,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _statChip(
                                      Icons.people_outline,
                                      '$learners students',
                                    ),
                                    _statChip(
                                      Icons.class_outlined,
                                      '$lessons lessons',
                                    ),
                                    _statChip(
                                      Icons.calendar_today_outlined,
                                      dateStr,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (status == 'DRAFT')
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditCoursePage(courseId: courseId),
                                  ),
                                ).then((_) => _fetchCoursesData());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF20B486),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            )
                          else
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditCoursePage(courseId: courseId),
                                  ),
                                ).then((_) => _fetchCoursesData());
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475569),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'View Detail',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared UI micro-components ───────────────────────────────────────────

  Widget _badge({
    required String label,
    required Color bg,
    required Color fg,
    Color? border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

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

  Widget _buildPagination() {
    if (_groupedCourses.isEmpty) return const SizedBox();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: _currentPage > 1 ? () {
            setState(() {
              _currentPage--;
            });
          } : null,
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
          'Page $_currentPage of $_totalPages',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _currentPage < _totalPages ? () {
            setState(() {
              _currentPage++;
            });
          } : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _currentPage < _totalPages ? Colors.white : const Color(0xFFF1F5F9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: _currentPage < _totalPages ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseCardWrapper<T> extends StatefulWidget {
  final T group;
  final Widget Function(T group, bool isHovered) buildCard;

  const _CourseCardWrapper({required this.group, required this.buildCard});

  @override
  State<_CourseCardWrapper<T>> createState() => _CourseCardWrapperState<T>();
}

class _CourseCardWrapperState<T> extends State<_CourseCardWrapper<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.buildCard(widget.group, _isHovered),
    );
  }
}
