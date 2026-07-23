import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/file_picker_helper.dart';
import 'add_multiple_choice_question_page.dart';
import '../../../data/repositories/trainer_ai_recommendation_repository.dart';

class AddNewQuestionPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final int sectionId;
  final String sectionTitle;
  final Function(List<int> newQuestionIds) onQuestionCreated;

  const AddNewQuestionPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.sectionIndex,
    required this.sectionId,
    required this.sectionTitle,
    required this.onQuestionCreated,
  });

  @override
  State<AddNewQuestionPage> createState() => _AddNewQuestionPageState();
}

class _AddNewQuestionPageState extends State<AddNewQuestionPage> {
  final AuthService _authService = AuthService();

  // AI inputs
  final TextEditingController _topicSeedController = TextEditingController();
  int _aiQuantity = 2;

  int _aiDifficultyId = 14;
  int _aiCategoryId = 1;
  int _aiSkillId = 1; // alias for category/skill (if you map separately later)
  String? _selectedSkillType;

  final TrainerAiQuestionRepository _aiRepo = TrainerAiQuestionRepository();
  bool _isGeneratingByAi = false;

  // SINGLE mode: list of generated questions so trainer can edit/reorder
  final List<Map<String, dynamic>> _singleQuestions = [];

  // Question details
  String _questionType = 'SINGLE'; // 'SINGLE' or 'MULTIPLE'
  String? _pdfName;
  String? _pdfSize;
  bool _isUploadingPdf = false;
  double _pdfUploadProgress = 0.0;
  final GlobalKey _dropZoneKey = GlobalKey();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with 1 empty question
    _addSingleQuestion();

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

  void _addSingleQuestion() {
    setState(() {
      _singleQuestions.add({
        'questionTextController': TextEditingController(text: ''),
        'hintController': TextEditingController(text: ''),
        'options': [
          {
            'textController': TextEditingController(text: ''),
            'isCorrect': true,
            'explanationController': TextEditingController(),
          },
          {
            'textController': TextEditingController(text: ''),
            'isCorrect': false,
            'explanationController': TextEditingController(),
          },
        ],
      });
    });
  }

  Future<void> _processPdfFile(PickedFile file) async {
    final double sizeInMb = file.bytes.length / (1024 * 1024);
    if (sizeInMb > 50.0) {
      ToastHelper.showError(context, 'File size exceeds 50MB limit.');
      return;
    }
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      ToastHelper.showError(context, 'Only PDF files are accepted.');
      return;
    }

    setState(() {
      _isUploadingPdf = true;
      _pdfName = file.name;
      _pdfSize = '${sizeInMb.toStringAsFixed(2)} MB';
      _pdfUploadProgress = 0.0;
    });

    const int totalSteps = 20;
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;

      setState(() {
        _pdfUploadProgress = i / totalSteps;
      });
    }

    setState(() {
      _isUploadingPdf = false;
    });
    ToastHelper.showSuccess(context, 'PDF document uploaded successfully.');
  }

  Future<void> _handlePdfUpload() async {
    try {
      final file = await pickPdf();
      if (file != null) {
        await _processPdfFile(file);
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      ToastHelper.showError(context, 'Failed to pick file.');
    }
  }

  void _removePdf() {
    setState(() {
      _pdfName = null;
      _pdfSize = null;
      _isUploadingPdf = false;
      _pdfUploadProgress = 0.0;
    });
  }

  Future<void> _saveQuestion() async {
    if (_singleQuestions.isEmpty) {
      ToastHelper.showError(
        context,
        'Please add or generate a question first.',
      );
      return;
    }

    // Validate ALL questions before saving ANY
    for (int i = 0; i < _singleQuestions.length; i++) {
      final q = _singleQuestions[i];
      final text = (q['questionTextController'] as TextEditingController).text
          .trim();
      if (text.isEmpty) {
        ToastHelper.showError(
          context,
          'Please enter question text for question ${i + 1}.',
        );
        return;
      }

      final opts = q['options'] as List<Map<String, dynamic>>;
      bool hasCorrect = false;
      for (final opt in opts) {
        final optText = (opt['textController'] as TextEditingController).text
            .trim();
        if (optText.isEmpty) {
          ToastHelper.showError(
            context,
            'Please fill in all option texts for question ${i + 1}.',
          );
          return;
        }
        if (opt['isCorrect'] == true) hasCorrect = true;
      }
      if (!hasCorrect) {
        ToastHelper.showError(
          context,
          'Please select at least one correct answer for question ${i + 1}.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        ToastHelper.showError(context, 'Session expired. Please log in again.');
        setState(() => _isSaving = false);
        return;
      }

      List<int> newIds = [];
      for (final q in _singleQuestions) {
        final questionText =
            (q['questionTextController'] as TextEditingController).text.trim();
        final explanation = (q['hintController'] as TextEditingController).text
            .trim();
        final opts = q['options'] as List<Map<String, dynamic>>;

        List<Map<String, dynamic>> payloadOptions = [];
        for (final opt in opts) {
          payloadOptions.add({
            'optionText': (opt['textController'] as TextEditingController).text
                .trim(),
            'isCorrect': opt['isCorrect'] as bool,
          });
        }

        final body = {
          'sectionId': widget.sectionId,
          'questionText': questionText,
          'explanation': explanation,
          'categoryId': _aiCategoryId,
          'skillParamId': _aiSkillId,
          'difficultyId': _aiDifficultyId,
          'options': payloadOptions,
        };

        final response = await http.post(
          Uri.parse('${EnvConfig.v1BaseUrl}/trainer/questions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          final resData = jsonDecode(response.body);
          newIds.add(resData['id'] as int);
        } else {
          throw Exception(
            jsonDecode(response.body)['error'] ?? 'Failed to save question',
          );
        }
      }

      ToastHelper.showSuccess(
        context,
        'Saved ${newIds.length} question(s) successfully!',
      );
      widget.onQuestionCreated(newIds);
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving question: $e');
      ToastHelper.showError(
        context,
        e.toString().replaceAll('Exception:', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose generated model controllers
    for (final q in _singleQuestions) {
      (q['questionTextController'] as TextEditingController).dispose();
      (q['hintController'] as TextEditingController).dispose();
      final opts = q['options'] as List<Map<String, dynamic>>;
      for (final opt in opts) {
        (opt['textController'] as TextEditingController).dispose();
        (opt['explanationController'] as TextEditingController).dispose();
      }
    }
    _singleQuestions.clear();

    if (kIsWeb) {
      unregisterDragDrop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Row matching select_quiz_questions_page and create_lesson_page
          _buildHeader(context),
          // Main Body
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Sidebar Panel
                _buildLeftSidebar(),
                // Main Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildMainForm(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                onTap: () => Navigator.pop(context),
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
                onTap: () => Navigator.pop(context),
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
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Create New Quiz',
                  style: TextStyle(
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
                'Create New Question',
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

  Widget _buildLeftSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEFF2F5))),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'COURSE CONTENT MANAGEMENT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.8,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          // Step 1: Introduction
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFEFF2F5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2F9F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF20B486),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Introduction',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF20B486),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Step 2: Syllabus
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF20B486)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: const Color(0xFF20B486)),
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
                            color: const Color(0xFF20B486),
                            width: 1.5,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '2',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF20B486),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Syllabus',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'In progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Progress Overview Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFF2F5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Progress Overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1/3 steps completed successfully. Complete the remaining steps to publish the course.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.4,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE2E8F0),
                    foregroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.send_outlined, size: 14),
                  label: const Text(
                    'Submit for Review',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'submit once 100% completed',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation header with save draft
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECTION ${widget.sectionIndex + 1}: ${widget.sectionTitle.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Add New Question',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFF475569)),
                  SizedBox(width: 6),
                  Text(
                    'Draft saved 2m ago',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Layout columns
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Inputs & PDF Upload
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEFF2F5)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AI Generate
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Generate by AI (Single Question)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _topicSeedController,
                            minLines: 1,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText:
                                  'Topic / seed (vd: Present Simple vs Present Continuous)',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Quantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (_aiQuantity > 1) _aiQuantity--;
                                        });
                                      },
                                    ),
                                    Container(
                                      width: 40,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$_aiQuantity',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (_aiQuantity < 10) _aiQuantity++;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Difficulty Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _aiDifficultyId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'Outfit',
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF64748B),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 12, child: Text('Easy')),
                                  DropdownMenuItem(value: 13, child: Text('Medium')),
                                  DropdownMenuItem(value: 14, child: Text('Hard')),
                                  DropdownMenuItem(value: 15, child: Text('Very Hard')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _aiDifficultyId = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // SkillType Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedSkillType,
                                hint: const Text(
                                  'Select Skill Type (Optional)',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'Outfit',
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF64748B),
                                ),
                                items:
                                    [
                                      'Conversation/Short Sentences',
                                      'Synonym',
                                      'Antonym',
                                      'Pronunciation',
                                      'Grammar',
                                      'Sentence Meaning',
                                      'Sentence Combining',
                                      'Fill in Blank',
                                      'Reading Comprehension',
                                      'Arrangement',
                                    ].map((String val) {
                                      return DropdownMenuItem<String>(
                                        value: val,
                                        child: Text(val),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSkillType = val;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isGeneratingByAi
                                ? null
                                : () async {
                                    await _handleGenerateByAI();
                                  },
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              size: 16,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B486),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            label: _isGeneratingByAi
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Generate by AI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fill question/options automatically. You still press Save manually.',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // PDF Attachment
                    const Text(
                      'PDF Attachment (Optional)',

                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    (_pdfName != null || _isUploadingPdf)
                        ? _buildPdfAttachedCard()
                        : InkWell(
                            key: _dropZoneKey,
                            onTap: _handlePdfUpload,
                            child: Container(
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 28,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Upload PDF Document',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1E293B),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Drag & drop or click to browse (Max 50MB)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 24),

                    // Description / Hint
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Type selection & options list
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question Type Selection
                  _buildQuestionTypeSelector(),

                  const SizedBox(height: 24),
                  // Answers Options list
                  _buildAnswersPanel(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Action Buttons Row
        const Divider(height: 1, color: Color(0xFFEFF2F5)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPdfAttachedCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF20B486)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Color(0xFF20B486), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pdfName ?? 'Uploading PDF...',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_pdfSize != null) ...[
                      Text(
                        _pdfSize!,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
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
                          fontSize: 11,
                          color: Color(0xFF20B486),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        'Uploaded successfully',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
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
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFEF4444),
              size: 18,
            ),
            onPressed: _isUploadingPdf ? null : _removePdf,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUESTION TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Multiple Choice
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddMultipleChoiceQuestionPage(
                          courseId: widget.courseId,
                          courseTitle: widget.courseTitle,
                          trainerName: widget.trainerName,
                          trainerInitials: widget.trainerInitials,
                          sections: widget.sections,
                          sectionIndex: widget.sectionIndex,
                          sectionId: widget.sectionId,
                          sectionTitle: widget.sectionTitle,
                          onQuestionCreated: widget.onQuestionCreated,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _questionType == 'MULTIPLE'
                          ? const Color(0xFF20B486)
                          : Colors.white,
                      border: Border.all(
                        color: _questionType == 'MULTIPLE'
                            ? const Color(0xFF20B486)
                            : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_box_outlined,
                          size: 16,
                          color: _questionType == 'MULTIPLE'
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Multiple Questions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _questionType == 'MULTIPLE'
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Single Choice
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _questionType = 'SINGLE';
                      // For SINGLE type, we enforce one correct option
                      for (final q in _singleQuestions) {
                        final opts = q['options'] as List<Map<String, dynamic>>;
                        int firstCorrectIdx = opts.indexWhere(
                          (opt) => opt['isCorrect'] == true,
                        );
                        if (firstCorrectIdx == -1 && opts.isNotEmpty) {
                          opts[0]['isCorrect'] = true;
                        } else {
                          for (int i = 0; i < opts.length; i++) {
                            opts[i]['isCorrect'] = (i == firstCorrectIdx);
                          }
                        }
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _questionType == 'SINGLE'
                          ? const Color(0xFF20B486)
                          : Colors.white,
                      border: Border.all(
                        color: _questionType == 'SINGLE'
                            ? const Color(0xFF20B486)
                            : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_square,
                          size: 16,
                          color: _questionType == 'SINGLE'
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Single Question',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _questionType == 'SINGLE'
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleGenerateByAI() async {
    final topicSeed = _topicSeedController.text.trim();
    if (topicSeed.isEmpty) {
      ToastHelper.showError(
        context,
        'Please enter Topic / seed before generating.',
      );
      return;
    }

    setState(() {
      _isGeneratingByAi = true;
    });

    try {
      final resp = await _aiRepo.generate(
        mode: 'SINGLE',
        sectionId: widget.sectionId,
        topicSeed: topicSeed,
        quantity: _aiQuantity,
        difficultyId: _aiDifficultyId,
        categoryId: _aiCategoryId,
        skillType: _selectedSkillType,
      );

      final generated = resp.questions ?? [];
      if (!mounted) return;
      if (generated.isEmpty) {
        ToastHelper.showError(
          context,
          'AI did not return SINGLE question data.',
        );
        return;
      }

      // Reset existing models/controllers for list
      for (final q in _singleQuestions) {
        (q['questionTextController'] as TextEditingController).dispose();
        (q['hintController'] as TextEditingController).dispose();
        final opts = q['options'] as List<Map<String, dynamic>>;
        for (final opt in opts) {
          (opt['textController'] as TextEditingController).dispose();
          (opt['explanationController'] as TextEditingController).dispose();
        }
      }
      _singleQuestions.clear();

      // Build models for ALL generated questions
      for (final q in generated) {
        final opts = <Map<String, dynamic>>[];
        for (final o in q.options) {
          opts.add({
            'textController': TextEditingController(text: o.optionText),
            'isCorrect': o.isCorrect,
            'explanationController': TextEditingController(),
          });
        }

        // Ensure only ONE correct for SINGLE
        final correctIndexes = <int>[];
        for (int i = 0; i < opts.length; i++) {
          if (opts[i]['isCorrect'] == true) correctIndexes.add(i);
        }
        if (correctIndexes.isEmpty && opts.isNotEmpty) {
          for (int i = 0; i < opts.length; i++) {
            opts[i]['isCorrect'] = i == 0;
          }
        } else if (correctIndexes.isNotEmpty) {
          final keep = correctIndexes.first;
          for (int i = 0; i < opts.length; i++) {
            opts[i]['isCorrect'] = i == keep;
          }
        }

        _singleQuestions.add({
          'questionTextController': TextEditingController(text: q.questionText),
          'hintController': TextEditingController(text: q.explanation),
          'options': opts,
        });
      }

      setState(() {});
      ToastHelper.showSuccess(
        context,
        'AI generated ${_singleQuestions.length} question(s).',
      );
    } catch (e) {
      debugPrint('Error generating by AI: $e');
      ToastHelper.showError(
        context,
        'AI generate failed: ${e.toString().replaceAll('Exception:', '').trim()}',
      );
    } finally {
      setState(() {
        _isGeneratingByAi = false;
      });
    }
  }

  Widget _buildAnswersPanel() {
    // SINGLE layout like MULTIPLE:
    // - Each question is an expandable card with header row (title + delete + arrow)
    // - Expanded content includes options editor (radio-like circle) + EXPLANATION field
    // - Add Option / Add Question buttons

    if (_singleQuestions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEFF2F5)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ANSWER DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Generate by AI or add question to start.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  final opts = <Map<String, dynamic>>[];
                  for (int i = 0; i < 4; i++) {
                    opts.add({
                      'textController': TextEditingController(text: ''),
                      'isCorrect': i == 0,
                      'explanationController': TextEditingController(),
                    });
                  }

                  _singleQuestions.add({
                    'questionTextController': TextEditingController(text: ''),
                    'hintController': TextEditingController(text: ''),
                    'options': opts,
                  });
                });
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 14, color: Color(0xFF475569)),
              label: const Text(
                'Add New Quesion',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ANSWER DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _singleQuestions.length,
            itemBuilder: (context, setIdx) {
              final set = _singleQuestions[setIdx];
              final String title = 'Question ${setIdx + 1}';

              final TextEditingController qTextCtrl =
                  set['questionTextController'] as TextEditingController;
              final TextEditingController expCtrl =
                  set['hintController'] as TextEditingController;
              final opts = set['options'] as List<Map<String, dynamic>>;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const Spacer(),
                          if (_singleQuestions.length > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                              onPressed: () {
                                setState(() {
                                  _singleQuestions.removeAt(setIdx);
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    // Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Question Text Input
                          const Text(
                            'QUESTION TEXT *',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: qTextCtrl,
                            minLines: 3,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: 'Enter your question here...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontFamily: 'Outfit',
                              ),
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFF20B486),
                                  width: 1,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Options list
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: opts.length,
                            itemBuilder: (context, optIdx) {
                              final opt = opts[optIdx];
                              final bool isCorrect = opt['isCorrect'] as bool;
                              final TextEditingController textCtrl =
                                  opt['textController']
                                      as TextEditingController;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? const Color(0xFFE2F9F3)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCorrect
                                        ? const Color(0xFF20B486)
                                        : const Color(0xFFE2E8F0),
                                    width: isCorrect ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          for (
                                            int i = 0;
                                            i < opts.length;
                                            i++
                                          ) {
                                            opts[i]['isCorrect'] =
                                                (i == optIdx);
                                          }
                                        });
                                      },
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: isCorrect
                                              ? const Color(0xFF20B486)
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isCorrect
                                                ? const Color(0xFF20B486)
                                                : const Color(0xFFCBD5E1),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isCorrect
                                            ? const Center(
                                                child: Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: textCtrl,
                                        minLines: 1,
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        decoration: const InputDecoration(
                                          hintText: 'Enter option text...',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1E293B),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFEF4444),
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        if (opts.length <= 1) {
                                          ToastHelper.showError(
                                            context,
                                            'Must have at least one option.',
                                          );
                                          return;
                                        }
                                        setState(() {
                                          opts.removeAt(optIdx);
                                          if (!opts.any(
                                                (o) => o['isCorrect'] == true,
                                              ) &&
                                              opts.isNotEmpty) {
                                            opts[0]['isCorrect'] = true;
                                          }
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Add Option
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                opts.add({
                                  'textController': TextEditingController(
                                    text: '',
                                  ),
                                  'isCorrect': false,
                                  'explanationController':
                                      TextEditingController(),
                                });
                              });
                            },
                            icon: const Icon(
                              Icons.add,
                              size: 14,
                              color: Color(0xFF20B486),
                            ),
                            label: const Text(
                              'Add Option',
                              style: TextStyle(
                                color: Color(0xFF20B486),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Explanation
                          const Text(
                            'EXPLANATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: expCtrl,
                            minLines: 3,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText:
                                  'Explain why this correct answer is selected...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontFamily: 'Outfit',
                              ),
                              fillColor: const Color(0xFFF8FAFC),
                              filled: true,
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: Color(0xFF20B486),
                                  width: 1,
                                ),
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              height: 1.4,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                final opts = <Map<String, dynamic>>[];
                for (int i = 0; i < 4; i++) {
                  opts.add({
                    'textController': TextEditingController(text: ''),
                    'isCorrect': i == 0,
                    'explanationController': TextEditingController(),
                  });
                }

                _singleQuestions.add({
                  'questionTextController': TextEditingController(text: ''),
                  'hintController': TextEditingController(text: ''),
                  'options': opts,
                });
              });
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 14, color: Color(0xFF475569)),
            label: const Text(
              'Add Question',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
