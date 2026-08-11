import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../domain/entities/exam.dart';
import '../exam/exam_detail_history_page.dart';
import '../../../services/hango_api.dart';
import '../../../utils/toast_helper.dart';

class ExamReviewDashboardDialog extends StatefulWidget {
  final int examId;
  final String examTitle;
  final int examExpectedCount;
  final String status;
  final bool isCourseManager;
  final VoidCallback onActionSuccess;
  final int? creatorId;
  final String? creatorName;
  final int? currentUserId;
  final VoidCallback? onEditExam;

  const ExamReviewDashboardDialog({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.examExpectedCount,
    required this.status,
    required this.isCourseManager,
    required this.onActionSuccess,
    this.creatorId,
    this.creatorName,
    this.currentUserId,
    this.onEditExam,
  });

  @override
  State<ExamReviewDashboardDialog> createState() =>
      _ExamReviewDashboardDialogState();
}

class _ExamReviewDashboardDialogState extends State<ExamReviewDashboardDialog> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  List<dynamic> _blocksData = [];

  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _difficulties = [];
  List<Map<String, dynamic>> _groupTypes = [];

  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  bool get _isOwnExam =>
      widget.creatorId != null &&
      widget.currentUserId != null &&
      widget.creatorId == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!_hasScrolledToBottom && _scrollController.hasClients) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  void _checkInitialScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.position.maxScrollExtent <= 0) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<HangoApi> _getApi() async {
    final token = await _authService.getToken();
    final String apiBaseUrl = EnvConfig.apiBaseUrl;
    return HangoApi(baseUrl: apiBaseUrl, token: token);
  }

  Future<void> _loadData() async {
    try {
      final api = await _getApi();
      final skills = await api.getSystemParameters('SKILL_TYPE');
      final difficulties = await api.getSystemParameters('DIFFICULTY');
      final groupTypes = await api.getSystemParameters('GROUP_TYPE');

      final response = await api.getExamQuestions(widget.examId);
      final blocksData = response['blocks'] as List? ?? [];

      if (mounted) {
        setState(() {
          _skills = skills;
          _difficulties = difficulties;
          _groupTypes = groupTypes;
          _blocksData = blocksData;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkInitialScroll();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.show(
          context,
          'Failed to load exam data: $e',
          isError: true,
        );
      }
    }
  }

  String? _getParamName(List<Map<String, dynamic>> list, dynamic id) {
    if (id == null) return null;
    final found = list.firstWhere(
      (element) => element['id'].toString() == id.toString(),
      orElse: () => {},
    );
    return found['paramValue']?.toString();
  }

  Future<void> _updateExamStatus(String newStatus) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final String apiBaseUrl = EnvConfig.v1BaseUrl;
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/trainer/exams/${widget.examId}/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context); // close dialog
          widget.onActionSuccess();
        }
      } else {
        if (mounted) {
          ToastHelper.show(context, 'Error updating status', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Error: $e', isError: true);
      }
    }
  }

  void _publishExamAsManager() async {
    try {
      await CourseManagerApi().publishExam(widget.examId);
      if (mounted) {
        ToastHelper.show(context, 'Exam approved and published successfully!');
        Navigator.pop(context); // close dialog
        widget.onActionSuccess();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Error approving exam: $e', isError: true);
      }
    }
  }

  void _showRejectDialog() {
    bool rejectGeneral = false;
    final TextEditingController rejectGeneralCtrl = TextEditingController();
    bool rejectQuestions = false;
    final TextEditingController rejectQuestionsCtrl = TextEditingController();
    bool rejectOptions = false;
    final TextEditingController rejectOptionsCtrl = TextEditingController();
    bool rejectOther = false;
    final TextEditingController rejectOtherCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setStateInner) {
            return AlertDialog(
              title: const Text(
                'Rejection Checklist',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check the issues below and provide details for the Trainer:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChecklistItem(
                      setStateInner,
                      'General Info & Settings (Title, Passing Score, Expected Count, etc.)',
                      rejectGeneral,
                      (val) => rejectGeneral = val ?? false,
                      rejectGeneralCtrl,
                      'Missing specific keywords in title, wrong passing score...',
                    ),
                    _buildChecklistItem(
                      setStateInner,
                      'Questions & Passages (Unclear wording, typos, missing context)',
                      rejectQuestions,
                      (val) => rejectQuestions = val ?? false,
                      rejectQuestionsCtrl,
                      'Question 5 has typo, Passage 2 is unclear...',
                    ),
                    _buildChecklistItem(
                      setStateInner,
                      'Answers & Options (Wrong correct option, missing distractors)',
                      rejectOptions,
                      (val) => rejectOptions = val ?? false,
                      rejectOptionsCtrl,
                      'Question 3 has 2 correct answers...',
                    ),
                    _buildChecklistItem(
                      setStateInner,
                      'Other Issues',
                      rejectOther,
                      (val) => rejectOther = val ?? false,
                      rejectOtherCtrl,
                      'Please clarify the objective...',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(innerContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!rejectGeneral &&
                        !rejectQuestions &&
                        !rejectOptions &&
                        !rejectOther) {
                      ToastHelper.showError(
                        innerContext,
                        'Please check at least one issue.',
                      );
                      return;
                    }
                    List<String> reasons = [];
                    if (rejectGeneral)
                      reasons.add(
                        '- [x] **General Info & Settings:**\\n ${rejectGeneralCtrl.text}',
                      );
                    if (rejectQuestions)
                      reasons.add(
                        '- [x] **Questions & Passages:**\\n ${rejectQuestionsCtrl.text}',
                      );
                    if (rejectOptions)
                      reasons.add(
                        '- [x] **Answers & Options:**\\n ${rejectOptionsCtrl.text}',
                      );
                    if (rejectOther)
                      reasons.add(
                        '- [x] **Other Issues:**\\n ${rejectOtherCtrl.text}',
                      );
                    String finalReason = reasons.join("\\n\\n");

                    Navigator.pop(innerContext);

                    try {
                      await CourseManagerApi().rejectExam(
                        widget.examId,
                        reason: finalReason,
                      );
                      if (mounted) {
                        ToastHelper.show(
                          context,
                          'Exam rejected successfully!',
                        );
                        Navigator.pop(context); // close review dialog
                        widget.onActionSuccess();
                      }
                    } catch (e) {
                      if (mounted)
                        ToastHelper.show(
                          context,
                          'Error rejecting exam: $e',
                          isError: true,
                        );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text(
                    'Reject Exam',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChecklistItem(
    StateSetter setStateInner,
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => setStateInner(() => onChanged(v)),
              activeColor: const Color(0xFFEF4444),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (value)
          Padding(
            padding: const EdgeInsets.only(
              left: 40.0,
              bottom: 12.0,
              right: 8.0,
            ),
            child: TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFFEF2F2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF8FAFC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exam Review: ${widget.examTitle}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusBadge(widget.status),
                  const SizedBox(width: 16),
                  Text(
                    'Expected Questions: ${widget.examExpectedCount}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  if (widget.creatorId != null) ...[
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOwnExam
                          ? 'Me'
                          : (widget.creatorName ?? 'Unknown'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);
    String label = status.toUpperCase();

    if (label == 'PENDING') {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFD97706);
    } else if (label == 'PUBLISHED') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
    } else if (label == 'REJECTED') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
    } else if (label == 'HIDDEN') {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_blocksData.isEmpty) {
      return const Center(
        child: Text(
          'No questions found.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _blocksData.length,
      itemBuilder: (context, index) {
        final block = _blocksData[index];
        return _buildBlockCard(block, index);
      },
    );
  }

  Widget _buildBlockCard(dynamic block, int blockIndex) {
    final String passage = block['passageText']?.toString() ?? '';
    final isGroup = passage.isNotEmpty;
    final subQs = block['subQuestions'] as List? ?? [];
    final categoryName = _getParamName(_groupTypes, block['categoryId']);

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Block ${blockIndex + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (categoryName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (isGroup) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  passage,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...subQs
                .asMap()
                .entries
                .map((e) => _buildQuestionItem(e.value, e.key))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(dynamic qData, int index) {
    final skillName = _getParamName(_skills, qData['skillParamId']);
    final diffName = _getParamName(_difficulties, qData['difficultyId']);
    final opts = qData['options'] as List? ?? [];
    final explanation = qData['explanation']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'Q${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qData['questionText']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (skillName != null || diffName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (skillName != null)
                            _buildTag(
                              skillName,
                              const Color(0xFFF0FDF4),
                              const Color(0xFF16A34A),
                            ),
                          if (skillName != null && diffName != null)
                            const SizedBox(width: 8),
                          if (diffName != null)
                            _buildTag(
                              diffName,
                              const Color(0xFFFEF2F2),
                              const Color(0xFFDC2626),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: opts.map((opt) => _buildOption(opt)).toList(),
            ),
          ),
          if (explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFEF08A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        explanation,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 14,
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

  Widget _buildTag(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOption(dynamic opt) {
    final isCorrect = opt['isCorrect'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCorrect
                ? const Color(0xFF22C55E)
                : const Color(0xFFCBD5E1),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              opt['optionText']?.toString() ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isCorrect
                    ? const Color(0xFF166534)
                    : const Color(0xFF475569),
                fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isOwnExam &&
              widget.status.toUpperCase() == 'REJECTED' &&
              widget.onEditExam != null) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // close dialog
                widget.onEditExam!();
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text(
                'Edit Exam',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
          if (widget.isCourseManager &&
              (widget.status.toUpperCase() == 'SUBMITTED' ||
                  widget.status.toUpperCase() == 'PENDING')) ...[
            const SizedBox(width: 12),
            if (!_hasScrolledToBottom)
              const Text(
                '(Scroll to bottom to review)',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _hasScrolledToBottom ? _showRejectDialog : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFEF4444),
                disabledForegroundColor: Colors.grey,
                side: BorderSide(
                  color: _hasScrolledToBottom
                      ? const Color(0xFFEF4444)
                      : Colors.grey,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Reject',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _hasScrolledToBottom
                  ? () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'Approve Exam',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            'Are you sure you want to approve and publish the exam "${widget.examTitle}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _publishExamAsManager();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF20B486),
                              ),
                              child: const Text(
                                'Approve',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Approve & Publish',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (widget.isCourseManager &&
              widget.status.toUpperCase() == 'PUBLISHED') ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                final exam = Exam(
                  id: widget.examId.toString(),
                  title: widget.examTitle,
                  creatorName: 'Trainer',
                  questionCount: widget.examExpectedCount,
                  durationMinutes: 60,
                  rating: 5.0,
                  learnerCountFormatted: '0',
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamDetailHistoryPage(exam: exam),
                  ),
                );
              },
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text(
                'View as Learner',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _updateExamStatus('HIDDEN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Hide Exam',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          if (widget.isCourseManager &&
              widget.status.toUpperCase() == 'HIDDEN') ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _updateExamStatus('PUBLISHED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Unhide Exam',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
