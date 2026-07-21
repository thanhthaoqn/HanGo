import 'package:flutter/material.dart';

import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import '../trainer/matrix_management_page.dart';
import 'course_manager_dashboard_page.dart';
import 'course_manager_exams_page.dart';
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
  bool _isSidebarVisible = true;
  bool _isMockPreview = false;

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
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop && _isSidebarVisible)
            SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF20B486),
                          ),
                        )
                      : _buildContent(),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingTextStyle: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
              fontSize: 13,
            ),
            columns: const [
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('Trainer')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Content')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: courses
                .map(
                  (course) => DataRow(
                    cells: [
                      DataCell(_CourseTitleCell(course: course)),
                      DataCell(Text(course.creatorName)),
                      DataCell(Text(course.categoryName)),
                      DataCell(
                        Text(
                          '${course.sectionsCount} sections / ${course.lessonsCount} lessons',
                        ),
                      ),
                      DataCell(Text(_formatPrice(course.price))),
                      DataCell(_StatusPill(status: course.status)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View details',
                              onPressed: () => _showCourseDetail(course),
                              icon: const Icon(Icons.visibility_outlined),
                              color: const Color(0xFF475569),
                            ),
                            IconButton(
                              tooltip: 'Return to draft',
                              onPressed: _isPendingStatus(course.status)
                                  ? () => _rejectCourse(course)
                                  : null,
                              icon: const Icon(Icons.undo_outlined),
                              color: const Color(0xFFEF4444),
                            ),
                            IconButton.filled(
                              tooltip: 'Publish',
                              onPressed: _isPendingStatus(course.status)
                                  ? () => _publishCourse(course)
                                  : null,
                              icon: const Icon(Icons.check),
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF20B486),
                                disabledBackgroundColor: const Color(
                                  0xFFE2E8F0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  bool _isPendingStatus(String status) {
    final s = status.toUpperCase();
    return s == 'PENDING' || s == 'PENDING_APPROVAL';
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
            )
          else
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
            ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course Review',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
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
  bool _hasViewedAll = false;
  bool _showReasonInput = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfViewedAll();
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
    if (_hasViewedAll) return;
    _checkIfViewedAll();
  }

  void _checkIfViewedAll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // If the content is short enough to fit without scrolling, or scrolled to bottom
    if (maxScroll <= 0 || currentScroll >= maxScroll - 20) {
      setState(() {
        _hasViewedAll = true;
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
            if (!_hasViewedAll && _isPendingStatus(widget.course.status))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: const Color(0xFFFFFBEB),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please scroll down and review all information before approving or rejecting.',
                        style: TextStyle(color: Color(0xFF92400E), fontFamily: 'Outfit'),
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
                      _SyllabusPreview(sessions: widget.course.sessions),
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

  const _SyllabusPreview({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Syllabus',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        ...sessions.map((session) {
          final map = session is Map ? session : const {};
          final lessons = map['lessons'] as List? ?? const [];
          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              map['title']?.toString() ?? 'Untitled section',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
            ),
            subtitle: Text(
              '${lessons.length} lessons',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
            children: lessons.map((lesson) {
              final lessonMap = lesson is Map ? lesson : const {};
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.article_outlined,
                  color: Color(0xFF20B486),
                  size: 18,
                ),
                title: Text(
                  lessonMap['title']?.toString() ?? 'Untitled lesson',
                  style: const TextStyle(fontFamily: 'Outfit'),
                ),
                subtitle: Text(
                  lessonMap['itemType']?.toString() ?? 'lesson',
                  style: const TextStyle(fontFamily: 'Outfit'),
                ),
              );
            }).toList(),
          );
        }),
      ],
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
