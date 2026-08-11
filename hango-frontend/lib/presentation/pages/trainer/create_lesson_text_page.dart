import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../widgets/trainer_action_required_card.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:flutter/foundation.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../utils/file_picker_helper.dart';
import '../../../utils/toast_helper.dart';

class CreateLessonTextPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final Future<void> Function(List<dynamic> updatedSections) onSectionsChanged;
  final int? lessonIndex;
  final String? courseStatus;
  final String? rejectionReason;

  const CreateLessonTextPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.sectionIndex,
    required this.onSectionsChanged,
    this.lessonIndex,
    this.courseStatus,
    this.rejectionReason,
  });

  @override
  State<CreateLessonTextPage> createState() => _CreateLessonTextPageState();
}

class _CreateLessonTextPageState extends State<CreateLessonTextPage> {
  late List<dynamic> _localSections;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _learningObjectivesController =
      TextEditingController();
  final TextEditingController _estimatedTimeController =
      TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final MarkdownTextEditingController _questionController =
      MarkdownTextEditingController();

  // Upload states
  String? _uploadedImageUrl;

  String? _uploadedPdfName;
  bool _isUploadingPdf = false;
  double _pdfUploadProgress = 0.0;
  String? _pdfFileSizeStr;
  final GlobalKey _dropZoneKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);

    if (widget.lessonIndex != null &&
        widget.lessonIndex! <
            (_localSections[widget.sectionIndex]['lessons'] ?? []).length) {
      final lesson =
          _localSections[widget.sectionIndex]['lessons'][widget.lessonIndex!];
      _titleController.text = lesson['title'] ?? '';
      _codeController.text = lesson['lessonCode'] ?? '';
      _learningObjectivesController.text = lesson['learningObjectives'] ?? '';
      _estimatedTimeController.text =
          lesson['estimatedTimeMinutes']?.toString() ?? '';
      _descController.text = lesson['description'] ?? '';
      _questionController.text =
          lesson['questionText'] ?? lesson['content'] ?? '';
      _uploadedPdfName = (lesson['pdfName'] as String?)?.isNotEmpty == true
          ? lesson['pdfName']
          : null;
      _uploadedImageUrl =
          (lesson['questionImageUrl'] as String?)?.isNotEmpty == true
          ? lesson['questionImageUrl']
          : null;
      if (_uploadedPdfName != null && _uploadedPdfName!.isNotEmpty) {
        _pdfFileSizeStr = 'Attached';
      }

      final lessonId = lesson['id'];
      final isLocallyModified = lesson['isLocallyModified'] == true;
      if (lessonId is num && lessonId < 1000000000000 && !isLocallyModified) {
        _loadLessonDetailFromApi(lessonId.toInt());
      }
    }

    if (kIsWeb) {
      registerDragDrop((clientX, clientY, pickedFile) {
        if (_dropZoneKey.currentContext == null) return;
        final RenderBox renderBox =
            _dropZoneKey.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        if (clientX >= position.dx &&
            clientX <= position.dx + size.width &&
            clientY >= position.dy &&
            clientY <= position.dy + size.height) {
          _processPdfFile(pickedFile);
        }
      });
    }
  }

  void _loadLessonDetailFromApi(int lessonId) async {
    try {
      final repo = LessonRepository();
      final detail = await repo.fetchLessonDetail(lessonId);
      if (mounted) {
        setState(() {
          _titleController.text = detail.title;
          _questionController.text = detail.content;
          if (detail.lessonCode != null)
            _codeController.text = detail.lessonCode!;
          if (detail.learningObjectives != null)
            _learningObjectivesController.text = detail.learningObjectives!;
          if (detail.estimatedTimeMinutes != null)
            _estimatedTimeController.text = detail.estimatedTimeMinutes
                .toString();
        });
      }
    } catch (e) {
      debugPrint(
        'Error loading lesson detail from API in CreateLessonTextPage: $e',
      );
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      unregisterDragDrop();
    }
    _titleController.dispose();
    _codeController.dispose();
    _learningObjectivesController.dispose();
    _estimatedTimeController.dispose();
    _descController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _notifyParent() async {
    await widget.onSectionsChanged(_localSections);
  }

  Future<void> _processPdfFile(PickedFile file) async {
    final double sizeInMb = file.bytes.length / (1024 * 1024);
    if (sizeInMb > 50.0) {
      if (mounted) {
        ToastHelper.showError(context, 'File size exceeds 50MB limit!');
      }
      return;
    }
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      if (mounted) {
        ToastHelper.showError(context, 'Only PDF files are accepted.');
      }
      return;
    }

    setState(() {
      _isUploadingPdf = true;
      _uploadedPdfName = file.name;
      _pdfFileSizeStr = '${sizeInMb.toStringAsFixed(2)} MB';
      _pdfUploadProgress = 0.3; // Start progress
    });

    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/diqekap4o/raw/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(
          http.MultipartFile.fromBytes('file', file.bytes, filename: file.name),
        );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final uploadedUrl = data['secure_url'] ?? data['url'];

        setState(() {
          _uploadedPdfName = uploadedUrl;
          _pdfUploadProgress = 1.0;
        });

        if (mounted) {
          ToastHelper.showSuccess(
            context,
            'PDF document uploaded successfully.',
          );
        }
      } else {
        throw Exception('Failed to upload PDF. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      if (mounted) {
        ToastHelper.showError(context, 'Failed to upload PDF file.');
      }
      setState(() {
        _uploadedPdfName = null;
        _pdfFileSizeStr = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPdf = false;
        });
      }
    }
  }

  void _pickAndUploadPdf() async {
    try {
      final file = await pickPdf();
      if (file != null) {
        await _processPdfFile(file);
      }
    } catch (e) {
      debugPrint('Error picking or uploading PDF: $e');
      setState(() {
        _isUploadingPdf = false;
        _uploadedPdfName = null;
        _pdfFileSizeStr = null;
      });
    }
  }

  void _addMarkdownTag(String tagOpen, String tagClose) {
    final text = _questionController.text;
    final selection = _questionController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final start = selection.start;
      final end = selection.end;
      final selectedText = text.substring(start, end);

      // Case 1: The selection INCLUDES the tags (e.g., they selected "**bold**")
      if (tagOpen.isNotEmpty &&
          tagClose.isNotEmpty &&
          selectedText.startsWith(tagOpen) &&
          selectedText.endsWith(tagClose)) {
        final innerText = selectedText.substring(
          tagOpen.length,
          selectedText.length - tagClose.length,
        );
        final newText = text.replaceRange(start, end, innerText);
        _questionController.text = newText;
        _questionController.selection = TextSelection.collapsed(
          offset: start + innerText.length,
        );
        return;
      }

      // Case 2: The selection is INSIDE the tags (e.g., they selected "bold" inside "**bold**", or they just have blinking cursor inside "**|**")
      if (tagOpen.isNotEmpty &&
          tagClose.isNotEmpty &&
          start >= tagOpen.length &&
          end <= text.length - tagClose.length) {
        final before = text.substring(start - tagOpen.length, start);
        final after = text.substring(end, end + tagClose.length);
        if (before == tagOpen && after == tagClose) {
          final newText = text.replaceRange(
            start - tagOpen.length,
            end + tagClose.length,
            selectedText,
          );
          _questionController.text = newText;
          _questionController.selection = TextSelection.collapsed(
            offset: start - tagOpen.length + selectedText.length,
          );
          return;
        }
      }

      // Default: Add tags
      final newText = text.replaceRange(
        start,
        end,
        '$tagOpen$selectedText$tagClose',
      );
      _questionController.text = newText;
      // Put cursor inside or after tag
      _questionController.selection = TextSelection.collapsed(
        offset: start + tagOpen.length + selectedText.length,
      );
    } else {
      _questionController.text = '$text$tagOpen$tagClose';
    }
  }

  void _saveLesson() async {
    final title = _titleController.text.trim();
    final code = _codeController.text.trim();
    final objectives = _learningObjectivesController.text.trim();
    final estimatedTime =
        int.tryParse(_estimatedTimeController.text.trim()) ?? 0;
    final desc = _descController.text.trim();
    final question = _questionController.text.trim();

    if (title.isEmpty) {
      ToastHelper.showError(context, 'Please enter a lesson title');
      return;
    }
    if (title.length > 100) {
      ToastHelper.showError(
        context,
        'Lesson title cannot exceed 100 characters',
      );
      return;
    }
    if (code.length > 20) {
      ToastHelper.showError(context, 'Lesson code cannot exceed 20 characters');
      return;
    }
    if (desc.length > 500) {
      ToastHelper.showError(
        context,
        'Description cannot exceed 500 characters',
      );
      return;
    }
    if (objectives.length > 1000) {
      ToastHelper.showError(
        context,
        'Learning objectives cannot exceed 1000 characters',
      );
      return;
    }
    if (estimatedTime <= 0) {
      ToastHelper.showError(
        context,
        'Please enter a valid estimated time (> 0 minutes)',
      );
      return;
    }

    if (question.isEmpty) {
      ToastHelper.showError(context, 'Please enter the lesson content');
      return;
    }

    setState(() {
      final lessons = List.from(
        _localSections[widget.sectionIndex]['lessons'] ?? [],
      );

      final int displayOrder = widget.lessonIndex != null
          ? (lessons[widget.lessonIndex!]['displayOrder'] as num?)?.toInt() ??
                (lessons.length + 1)
          : (lessons.length + 1);

      final lessonData = {
        'id': widget.lessonIndex != null
            ? lessons[widget.lessonIndex!]['id']
            : DateTime.now().millisecondsSinceEpoch,
        'lessonCode': code,
        'title': title,
        'description': desc,

        // Must match backend/template key
        'lessonType': 'text',
        'displayOrder': displayOrder,

        // Backend/template content fields (text lesson)
        'content': question,
        'textContentMarkdown': question,
        'textContentHtml': '',

        // Media fields (optional in template)
        'mediaFileUrl': _uploadedPdfName ?? '',
        'mediaType': 'pdf',
        'mediaDurationSeconds': 0,
        'mediaSizeBytes': 0,
        'learningObjectives': objectives,
        'estimatedTimeMinutes': estimatedTime,
        'version': 'v1.0',
        'isLocallyModified': true,

        // Keep old keys (compatibility)
        'itemType': 'text',
        'questionText': question,
        'questionImageUrl': _uploadedImageUrl ?? '',
        'pdfName': _uploadedPdfName ?? '',
      };

      if (widget.lessonIndex != null) {
        lessons[widget.lessonIndex!] = lessonData;
      } else {
        lessons.add(lessonData);
      }
      _localSections[widget.sectionIndex]['lessons'] = lessons;
    });

    await _notifyParent();
    if (!mounted) return;
    ToastHelper.showSuccess(
      context,
      widget.lessonIndex != null
          ? 'Lesson updated successfully'
          : 'Lesson added successfully',
    );

    // Pop back to CreateLessonPage
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final section = _localSections[widget.sectionIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InternalAppHeader(isMobile: false),
          Expanded(
            child: isDesktop
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _buildTitleSection(),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 280,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  0,
                                  0,
                                  24,
                                ),
                                child: _buildLeftPanel(context),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  0,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildMainFormCard(section),
                                    const SizedBox(height: 24),
                                    _buildActionsRow(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 24),
                        _buildLeftPanel(context),
                        const SizedBox(height: 24),
                        _buildMainFormCard(section),
                        const SizedBox(height: 24),
                        _buildActionsRow(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _unusedLegacyHeader([bool isMobile = false]) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEFF2F5))),
      ),
      child: Row(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Courses',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                ' › ',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Text(
                  widget.courseTitle,
                  style: const TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                ' › ',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Create New Lesson',
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
          IconButton(
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: Color(0xFF4B5563),
              size: 24,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Text(
                widget.trainerName,
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
                child: Text(
                  widget.trainerInitials,
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
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '${widget.courseTitle} (Edit mode)',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final activeColor = const Color(0xFF20B486);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COURSE CONTENT MANAGEMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 16),
              // Item 1: Introduction
              InkWell(
                onTap: () {
                  Navigator.pop(context, 'goToIntroduction');
                },
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFEFF2F5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF94A3B8),
                                width: 1.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF94A3B8),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Introduction',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Item 2: Syllabus
              InkWell(
                onTap: () {
                  Navigator.pop(
                    context,
                  ); // Pops back to CreateLessonPage (Syllabus)
                },
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFEFF2F5)),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 4, color: activeColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: activeColor,
                                    width: 1.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '2',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: activeColor,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Syllabus',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TrainerActionRequiredCard(
          courseStatus: widget.courseStatus,
          rejectionReason: widget.rejectionReason,
        ),
        const SizedBox(height: 20),
        // Trainer Tips Card
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Stack(
            children: [
              // Background Watermark
              Positioned(
                right: -24,
                bottom: -24,
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 120,
                  color: const Color(0xFF20B486).withOpacity(0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF20B486).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFF20B486),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Trainer Insights',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Engaging videos and clear syllabus help students stay motivated. Consider adding short quizzes after each section to reinforce learning.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Explore more tips',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF20B486),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF20B486),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainFormCard(dynamic section) {
    final lessons = section['lessons'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.01),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded Section Header Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Folder icon
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF20B486),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['title'] ?? 'Untitled Section',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lessons.length} ${lessons.length == 1 ? "item" : "items"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 12),
                const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Lesson Code field
          const Text(
            'Lesson Code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: 'e.g. L01',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          // Lesson Title field
          const Text(
            'Lesson Title',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter lesson title',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Lesson Description field
          const Text(
            'Lesson Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter lesson description.....',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Learning Objectives field
          const Text(
            'Learning Objectives',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _learningObjectivesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter learning objectives (one per line).....',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Content Type field (Pre-filled Text)
          const Text(
            'Content Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // light grey pre-filled
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Text',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Question card block
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Text Header Label
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Text *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B5563),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Rich Editor Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.format_bold,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                        tooltip: 'Bold',
                        onPressed: () {
                          _addMarkdownTag('**', '**');
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(
                          Icons.format_italic,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                        tooltip: 'Italic',
                        onPressed: () {
                          _addMarkdownTag('*', '*');
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(
                          Icons.format_list_bulleted,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                        tooltip: 'Bullet List',
                        onPressed: () {
                          _addMarkdownTag('- ', '');
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(
                          Icons.link,
                          size: 18,
                          color: Color(0xFF475569),
                        ),
                        tooltip: 'Link',
                        onPressed: () {
                          _addMarkdownTag('[', '](url)');
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Question Text Input
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _questionController,
                    maxLines: 8,
                    onChanged: (val) {
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      hintText:
                          'Enter your lesson content here... (Format highlights in real-time)',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontFamily: 'Outfit',
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // PDF Attachment (Optional)
          const Text(
            'PDF Attachment (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          if ((_uploadedPdfName == null || _uploadedPdfName!.isEmpty) &&
              !_isUploadingPdf)
            InkWell(
              key: _dropZoneKey,
              onTap: _pickAndUploadPdf,
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: DashedRoundedBorderPainter(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: 12,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.description_outlined,
                        color: Color(0xFF64748B),
                        size: 36,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upload PDF Document',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Drag & drop or click to browse (Max 50MB)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.01),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _uploadedPdfName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (_pdfFileSizeStr != null) ...[
                              Text(
                                _pdfFileSizeStr!,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (_isUploadingPdf)
                              Text(
                                'Uploading... ${(_pdfUploadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Color(0xFF20B486),
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              const Text(
                                'Uploaded successfully',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Color(0xFF20B486),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        if (_isUploadingPdf) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _pdfUploadProgress,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF20B486),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFEF4444),
                        size: 16,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _uploadedPdfName = null;
                        _pdfFileSizeStr = null;
                        _isUploadingPdf = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // Estimated Time input
          const Text(
            'Estimated Time (Minutes)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _estimatedTimeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g. 15',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: const Icon(
                Icons.timer_outlined,
                color: Color(0xFF94A3B8),
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        const Text(
          'Draft saved automatically just now',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontFamily: 'Outfit',
          ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4B5563),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Back',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saveLesson,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            widget.lessonIndex != null ? 'Save Changes' : 'Add Lesson +',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = dashWidth;
        if (distance + len > metric.length) {
          dashedPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashedPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class MarkdownTextEditingController extends TextEditingController {
  MarkdownTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|#+\s[^\n]+|\[[^\]]+\]\([^)]+\))',
    );

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        final matchedText = match[0]!;
        TextStyle matchStyle = style ?? const TextStyle();

        if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
          final content = matchedText.substring(2, matchedText.length - 2);
          children.add(
            const TextSpan(
              text: '**',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          );
          children.add(
            TextSpan(
              text: content,
              style: matchStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          );
          children.add(
            const TextSpan(
              text: '**',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          );
        } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
          final content = matchedText.substring(1, matchedText.length - 1);
          children.add(
            const TextSpan(
              text: '*',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          );
          children.add(
            TextSpan(
              text: content,
              style: matchStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: const Color(0xFF0F172A),
              ),
            ),
          );
          children.add(
            const TextSpan(
              text: '*',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          );
        } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
          final content = matchedText.substring(1, matchedText.length - 1);
          children.add(
            const TextSpan(
              text: '`',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          );
          children.add(
            TextSpan(
              text: content,
              style: matchStyle.copyWith(
                fontFamily: 'monospace',
                backgroundColor: const Color(0xFFF1F5F9),
                color: const Color(0xFF0F172A),
              ),
            ),
          );
          children.add(
            const TextSpan(
              text: '`',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          );
        } else if (matchedText.startsWith('#')) {
          final matchIndex = matchedText.indexOf(' ');
          if (matchIndex != -1) {
            final hashes = matchedText.substring(0, matchIndex + 1);
            final content = matchedText.substring(matchIndex + 1);
            children.add(
              TextSpan(
                text: hashes,
                style: const TextStyle(fontSize: 0, color: Colors.transparent),
              ),
            );
            children.add(
              TextSpan(
                text: content,
                style: matchStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (style?.fontSize ?? 14) * 1.15,
                  color: const Color(0xFF20B486),
                ),
              ),
            );
          } else {
            children.add(TextSpan(text: matchedText, style: matchStyle));
          }
        } else if (matchedText.startsWith('[')) {
          final closeBracket = matchedText.indexOf(']');
          final closeParen = matchedText.lastIndexOf(')');
          if (closeBracket != -1 && closeParen != -1) {
            final textPart = matchedText.substring(1, closeBracket);
            final urlPart = matchedText.substring(
              closeBracket,
              closeParen + 1,
            ); // contains ](url)
            children.add(
              const TextSpan(
                text: '[',
                style: TextStyle(fontSize: 0, color: Colors.transparent),
              ),
            );
            children.add(
              TextSpan(
                text: textPart,
                style: matchStyle.copyWith(
                  color: const Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            );
            children.add(
              TextSpan(
                text: urlPart,
                style: const TextStyle(fontSize: 0, color: Colors.transparent),
              ),
            );
          } else {
            children.add(TextSpan(text: matchedText, style: matchStyle));
          }
        }
        return '';
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}
