import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';

class CourseReviewDashboardDialog extends StatefulWidget {
  final CourseReviewCourse course;
  final ValueChanged<String> onReject;
  final VoidCallback onPublish;
  final VoidCallback? onHide;
  final VoidCallback? onUnhide;

  const CourseReviewDashboardDialog({
    super.key,
    required this.course,
    required this.onReject,
    required this.onPublish,
    this.onHide,
    this.onUnhide,
  });

  @override
  State<CourseReviewDashboardDialog> createState() => _CourseReviewDashboardDialogState();
}

class _CourseReviewDashboardDialogState extends State<CourseReviewDashboardDialog> {
  bool _showReasonInput = false;

  bool _rejectGeneral = false;
  final TextEditingController _rejectGeneralCtrl = TextEditingController();

  bool _rejectContent = false;
  final TextEditingController _rejectContentCtrl = TextEditingController();

  bool _rejectQuiz = false;
  final TextEditingController _rejectQuizCtrl = TextEditingController();

  bool _rejectOther = false;
  final TextEditingController _rejectOtherCtrl = TextEditingController();

  String? _selectedLessonKey;
  Map<String, dynamic>? _selectedLessonData;
  String? _selectedItemType;

  // Track which lesson IDs have been opened
  final Set<String> _viewedLessonKeys = {};
  late int _totalLessons;

  bool get _hasViewedAll {
    if (_totalLessons == 0) return true;
    return _viewedLessonKeys.length >= _totalLessons;
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
  }

  @override
  void dispose() {
    _rejectGeneralCtrl.dispose();
    _rejectContentCtrl.dispose();
    _rejectQuizCtrl.dispose();
    _rejectOtherCtrl.dispose();
    super.dispose();
  }

  void _selectLesson(String sectionId, int lessonIndex, Map<String, dynamic> lessonMap) {
    final key = '${sectionId}_$lessonIndex';
    setState(() {
      _selectedLessonKey = key;
      _selectedLessonData = lessonMap;
      _selectedItemType = lessonMap['itemType']?.toString().toLowerCase() ?? 'text';
      _viewedLessonKeys.add(key);
      _showReasonInput = false; // reset reject state on change
    });
  }

  bool _isPendingStatus(String status) {
    final s = status.toUpperCase();
    return s == 'PENDING' || s == 'PENDING_APPROVAL';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF8FAFC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 850),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Pane: Overview & Syllabus
              SizedBox(
                width: 380,
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildSidebarHeader(),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCourseInfo(),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              _buildSyllabusList(),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      _buildActionFooter(),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
              // Right Pane: Lesson Content
              Expanded(
                child: _selectedLessonData == null
                    ? _buildEmptyState()
                    : _buildLessonPreview(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F1),
                  borderRadius: BorderRadius.circular(12),
                  image: widget.course.thumbnailUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.course.thumbnailUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.course.thumbnailUrl.isEmpty
                    ? const Icon(Icons.school_outlined, color: Color(0xFF20B486), size: 28)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(status: widget.course.status),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(Icons.person_outline, 'Trainer', widget.course.creatorName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.category_outlined, 'Category', widget.course.categoryName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.bar_chart, 'Level', widget.course.difficultyName),
          const SizedBox(height: 12),
          if (widget.course.suggestedPrice != null && widget.course.suggestedPrice != widget.course.price)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      const Text(
                        'Price Negotiation',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Suggested Price',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF7F1D1D)),
                          ),
                          Text(
                            _formatPrice(widget.course.suggestedPrice!),
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7F1D1D)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Desired Price',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF7F1D1D)),
                          ),
                          Text(
                            _formatPrice(widget.course.price),
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7F1D1D)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trainer\'s Reason:',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF991B1B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (widget.course.priceNote != null && widget.course.priceNote!.trim().isNotEmpty)
                        ? widget.course.priceNote!
                        : 'No reason provided by trainer (legacy course)',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontStyle: (widget.course.priceNote != null && widget.course.priceNote!.trim().isNotEmpty) ? FontStyle.normal : FontStyle.italic,
                      color: const Color(0xFF7F1D1D),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildInfoRow(Icons.payments_outlined, 'Price', _formatPrice(widget.course.price)),
          const SizedBox(height: 16),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: const Text(
                'Course Overview',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Color(0xFF1E293B),
                ),
              ),
              children: [
                if (widget.course.description.isNotEmpty) ...[
                  const Text(
                    'Description',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.course.description,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF334155), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.course.objectives.isNotEmpty) ...[
                  const Text(
                    'Objectives',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.course.objectives,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF334155), height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildSyllabusList() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Syllabus',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_viewedLessonKeys.length}/$_totalLessons viewed',
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.course.sessions.asMap().entries.map((sEntry) {
            final sIdx = sEntry.key;
            final session = sEntry.value;
            final map = session is Map ? session : const {};
            final lessons = map['lessons'] as List? ?? const [];
            final sectionId = map['id']?.toString() ?? 'sec-$sIdx';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${sIdx + 1}',
                          style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          map['title']?.toString() ?? 'Untitled Section',
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E293B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...lessons.asMap().entries.map((lEntry) {
                    final lIdx = lEntry.key;
                    final lessonMap = lEntry.value is Map ? lEntry.value as Map<String, dynamic> : <String, dynamic>{};
                    final lessonKey = '${sectionId}_$lIdx';
                    final isSelected = _selectedLessonKey == lessonKey;
                    final isViewed = _viewedLessonKeys.contains(lessonKey);
                    final itemType = lessonMap['itemType']?.toString().toLowerCase() ?? 'text';
                    final title = lessonMap['title']?.toString() ?? 'Untitled lesson';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4, left: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE6F7F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: InkWell(
                        onTap: () => _selectLesson(sectionId, lIdx, lessonMap),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                isViewed ? Icons.check_circle : _getIconForType(itemType),
                                size: 16,
                                color: isSelected
                                    ? const Color(0xFF20B486)
                                    : (isViewed ? const Color(0xFF20B486) : const Color(0xFF94A3B8)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF0F8B68) : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isPendingStatus(widget.course.status)) ...[
            if (!_hasViewedAll)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Review all lessons to enable publishing.',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            if (_showReasonInput) ...[
              const Text(
                'Rejection Checklist',
                style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check the issues below and provide details for the Trainer:',
                style: TextStyle(color: Color(0xFF4B5563), fontFamily: 'Outfit', fontSize: 13),
              ),
              const SizedBox(height: 12),
              
              // General Info Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('General Info (Title, Description, Image)', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                value: _rejectGeneral,
                activeColor: const Color(0xFFEF4444),
                onChanged: (val) => setState(() => _rejectGeneral = val ?? false),
              ),
              if (_rejectGeneral)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: TextField(
                    controller: _rejectGeneralCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: 'E.g., Thumbnail is blurry...',
                      filled: true,
                      fillColor: const Color(0xFFFEF2F2),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                    ),
                  ),
                ),

              // Content / Video Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Lesson Content (Video, Reading Material)', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                value: _rejectContent,
                activeColor: const Color(0xFFEF4444),
                onChanged: (val) => setState(() => _rejectContent = val ?? false),
              ),
              if (_rejectContent)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: TextField(
                    controller: _rejectContentCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: 'Specify Lesson (E.g., Lesson 2 video has no audio)...',
                      filled: true,
                      fillColor: const Color(0xFFFEF2F2),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                    ),
                  ),
                ),

              // Quiz Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Quiz & Assessment', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                value: _rejectQuiz,
                activeColor: const Color(0xFFEF4444),
                onChanged: (val) => setState(() => _rejectQuiz = val ?? false),
              ),
              if (_rejectQuiz)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: TextField(
                    controller: _rejectQuizCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: 'Specify Lesson (E.g., Lesson 3 quiz has wrong answer)...',
                      filled: true,
                      fillColor: const Color(0xFFFEF2F2),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                    ),
                  ),
                ),

              // Other Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Other Issues', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                value: _rejectOther,
                activeColor: const Color(0xFFEF4444),
                onChanged: (val) => setState(() => _rejectOther = val ?? false),
              ),
              if (_rejectOther)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: TextField(
                    controller: _rejectOtherCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                    decoration: InputDecoration(
                      hintText: 'Enter other reasons...',
                      filled: true,
                      fillColor: const Color(0xFFFEF2F2),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showReasonInput = false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_rejectGeneral && !_rejectContent && !_rejectQuiz && !_rejectOther) {
                          ToastHelper.showError(context, 'Please check at least one issue.');
                          return;
                        }
                        
                        // Construct Markdown
                        List<String> reasons = [];
                        
                        if (_rejectGeneral) {
                          String detail = _rejectGeneralCtrl.text.trim();
                          if (detail.isEmpty) detail = "Need to review general information.";
                          reasons.add("- [x] **General Info (Title, Description, Image):**\n  $detail");
                        }
                        
                        if (_rejectContent) {
                          String detail = _rejectContentCtrl.text.trim();
                          if (detail.isEmpty) detail = "Content issues found in lessons.";
                          reasons.add("- [x] **Lesson Content (Video, Material):**\n  $detail");
                        }
                        
                        if (_rejectQuiz) {
                          String detail = _rejectQuizCtrl.text.trim();
                          if (detail.isEmpty) detail = "Assessment issues found.";
                          reasons.add("- [x] **Quiz & Assessment:**\n  $detail");
                        }
                        
                        if (_rejectOther) {
                          String detail = _rejectOtherCtrl.text.trim();
                          if (detail.isNotEmpty) {
                            reasons.add("- [x] **Other Issues:**\n  $detail");
                          }
                        }
                        
                        String finalReason = reasons.join("\n\n");
                        widget.onReject(finalReason);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _hasViewedAll
                          ? () => setState(() => _showReasonInput = true)
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(color: _hasViewedAll ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasViewedAll ? widget.onPublish : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20B486),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Publish Course', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (widget.course.status.toUpperCase() == 'PUBLISHED') ...[
            ElevatedButton.icon(
              onPressed: widget.onHide,
              icon: const Icon(Icons.visibility_off_outlined, size: 18),
              label: const Text('Hide Course', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ] else if (widget.course.status.toUpperCase() == 'HIDDEN') ...[
            ElevatedButton.icon(
              onPressed: widget.onUnhide,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Unhide Course', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_lesson_outlined, size: 64, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select a lesson to review',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Content will appear here when you select a lesson from the syllabus.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonPreview() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getIconForType(_selectedItemType ?? 'text'), color: const Color(0xFF64748B), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedItemType?.toUpperCase() ?? 'TEXT',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedLessonData!['title']?.toString() ?? 'Untitled Lesson',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content Scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _renderLessonContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderLessonContent() {
    final type = _selectedItemType;
    if (type == 'video') {
      return _buildVideoLesson();
    } else if (type == 'quiz') {
      return _buildQuizLesson();
    } else {
      return _buildTextLesson();
    }
  }

  Widget _buildVideoLesson() {
    final description = _selectedLessonData!['description']?.toString() ?? '';
    final estimatedTime = _selectedLessonData!['estimatedTime']?.toString() ?? '10';

    final videoUrl = _selectedLessonData!['videoUrl']?.toString() ?? 
                     _selectedLessonData!['content']?.toString() ?? 
                     _selectedLessonData!['questionText']?.toString() ?? '';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: videoUrl.isNotEmpty 
                  ? _ReviewVideoPlayer(videoUrl: videoUrl)
                  : Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Text(
                          'No video URL provided',
                          style: TextStyle(color: Colors.white, fontFamily: 'Outfit'),
                        ),
                      ),
                    ),
              ),
            ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              'Estimated Time: $estimatedTime mins',
              style: const TextStyle(fontFamily: 'Outfit', color: Color(0xFF475569), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'About this video',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Color(0xFF334155), height: 1.6),
          ),
        ],
      ],
    );
  }

  Widget _buildTextLesson() {
    final content = _selectedLessonData!['questionText']?.toString() ?? _selectedLessonData!['content']?.toString() ?? '';
    final description = _selectedLessonData!['description']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty) ...[
          Text(
            description,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
        ],
        if (content.isNotEmpty)
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              color: Color(0xFF1E293B),
              height: 1.8,
            ),
          )
        else
          _buildNoContentBox(),
      ],
    );
  }

  Widget _buildQuizLesson() {
    final content = _selectedLessonData!['questionText']?.toString() ?? '';
    final description = _selectedLessonData!['description']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'QUESTION',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (content.isNotEmpty)
                Text(
                  content,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    height: 1.5,
                  ),
                )
              else
                const Text(
                  'No question text provided.',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              _buildMockQuizOption('A', 'Mock Option 1'),
              const SizedBox(height: 12),
              _buildMockQuizOption('B', 'Mock Option 2', isCorrect: true),
              const SizedBox(height: 12),
              _buildMockQuizOption('C', 'Mock Option 3'),
              const SizedBox(height: 12),
              _buildMockQuizOption('D', 'Mock Option 4'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMockQuizOption(String letter, String text, {bool isCorrect = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCorrect ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCorrect ? const Color(0xFF22C55E) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCorrect ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 15,
                fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                color: isCorrect ? const Color(0xFF166534) : const Color(0xFF334155),
              ),
            ),
          ),
          if (isCorrect)
            const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
        ],
      ),
    );
  }

  Widget _buildNoContentBox() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.article_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 16),
          Text(
            'No Content Provided',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF475569)),
          ),
          SizedBox(height: 8),
          Text(
            'The trainer has not added any detailed content for this lesson yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_fill;
      case 'quiz':
        return Icons.quiz;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.article;
    }
  }

  String _formatPrice(num price) {
    if (price <= 0) return 'Free';
    return '${price.toStringAsFixed(0)} VND';
  }
}

class _ReviewVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _ReviewVideoPlayer({required this.videoUrl});

  @override
  State<_ReviewVideoPlayer> createState() => _ReviewVideoPlayerState();
}

class _ReviewVideoPlayerState extends State<_ReviewVideoPlayer> {
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isYoutube = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant _ReviewVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _initializePlayer();
    }
  }

  String? _extractYouTubeVideoId(String url) {
    if (url.isEmpty) return null;
    final regex = RegExp(
      r'^(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
    });
    
    final ytId = _extractYouTubeVideoId(widget.videoUrl);
    if (ytId != null) {
      _isYoutube = true;
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: ytId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          mute: false,
          showFullscreenButton: true,
          loop: false,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    } else {
      _isYoutube = false;
      try {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
        await _videoPlayerController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
        );
      } catch (e) {
        debugPrint('Error initializing video player: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _disposeControllers() {
    _youtubeController?.close();
    _youtubeController = null;
    
    _chewieController?.dispose();
    _chewieController = null;
    
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)));
    }
    
    if (_isYoutube && _youtubeController != null) {
      return YoutubePlayer(controller: _youtubeController!, aspectRatio: 16 / 9);
    }
    
    if (!_isYoutube && _chewieController != null) {
      return Chewie(controller: _chewieController!);
    }
    
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Text(
          'Failed to load video',
          style: TextStyle(color: Colors.white, fontFamily: 'Outfit'),
        ),
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
    final displayText = normalized == 'PENDING_APPROVAL' ? 'PENDING' : normalized;
    final color = switch (normalized) {
      'PUBLISHED' => const Color(0xFF20B486),
      'PENDING' || 'PENDING_APPROVAL' => const Color(0xFFF59E0B),
      'REJECTED' => const Color(0xFFEF4444),
      'HIDDEN' => const Color(0xFFD97706),
      'DRAFT' => const Color(0xFF64748B),
      _ => const Color(0xFF64748B),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        displayText,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Outfit'),
      ),
    );
  }
}
