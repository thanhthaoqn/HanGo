import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  // Text inputs
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _hintController = TextEditingController();

  // AI inputs
  final TextEditingController _topicSeedController = TextEditingController();

  int _aiQuantity = 1; // number of SINGLE questions
  int _aiDifficultyId = 14;
  int _aiCategoryId = 1;
  int _aiSkillId = 1; // alias for category/skill (if you map separately later)

  final TrainerAiQuestionRepository _aiRepo = TrainerAiQuestionRepository();
  bool _isGeneratingByAi = false;

  // SINGLE mode: list of generated questions so trainer can edit/reorder
  final List<Map<String, dynamic>> _singleQuestions = [];

  int _editingQuestionIndex = 0;

  // Question details
  String _questionType = 'SINGLE'; // 'SINGLE' or 'MULTIPLE'
  String? _pdfName;
  String? _pdfSize;
  bool _isUploadingPdf = false;
  double _pdfUploadProgress = 0.0;
  final GlobalKey _dropZoneKey = GlobalKey();

  // Legacy option list state (kept but used only by active question editor)
  final List<Map<String, dynamic>> _options = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with 2 options
    _addOption(text: '', isCorrect: true);
    _addOption(text: '', isCorrect: false);

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

  void _addOption({String text = '', bool isCorrect = false}) {
    final textCtrl = TextEditingController(text: text);
    final expCtrl = TextEditingController();
    setState(() {
      _options.add({
        'textController': textCtrl,
        'isCorrect': isCorrect,
        'explanationController': expCtrl,
      });
    });
  }

  void _removeOption(int index) {
    _syncEditorToModel();

    if (_options.length <= 1) {
      ToastHelper.showError(
        context,
        'Questions must have at least one option.',
      );
      return;
    }
    setState(() {
      _options[index]['textController'].dispose();
      _options[index]['explanationController'].dispose();
      _options.removeAt(index);
    });
  }

  void _handleOptionSelect(int index) {
    setState(() {
      if (_questionType == 'SINGLE') {
        // Deselect all others
        for (int i = 0; i < _options.length; i++) {
          _options[i]['isCorrect'] = (i == index);
        }
      } else {
        // Toggle checkbox
        _options[index]['isCorrect'] = !_options[index]['isCorrect'];
      }
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
    if (_editingQuestionIndex < 0 ||
        _editingQuestionIndex >= _singleQuestions.length) {
      ToastHelper.showError(context, 'Invalid question selection.');
      return;
    }

    // Always save from the currently edited model (prevents UI<->editor mismatch)
    final current =
        _singleQuestions[_editingQuestionIndex] as Map<String, dynamic>;
    final questionText =
        (current['questionTextController'] as TextEditingController).text
            .trim();
    if (questionText.isEmpty) {
      ToastHelper.showError(context, 'Please enter the question text.');
      return;
    }

    final List<Map<String, dynamic>> currentOptions =
        (current['options'] as List<Map<String, dynamic>>);

    List<Map<String, dynamic>> payloadOptions = [];
    bool hasCorrectAnswer = false;
    for (final opt in currentOptions) {
      final text = (opt['textController'] as TextEditingController).text.trim();
      if (text.isEmpty) {
        ToastHelper.showError(context, 'Please fill in all option texts.');
        return;
      }
      final bool isCorrect = opt['isCorrect'] as bool;
      if (isCorrect) {
        hasCorrectAnswer = true;
      }
      payloadOptions.add({'optionText': text, 'isCorrect': isCorrect});
    }

    if (!hasCorrectAnswer) {
      ToastHelper.showError(
        context,
        'Please select at least one correct answer.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Ensure we persist latest editor input into current model
      _syncEditorToModel();

      final token = await _authService.getToken();

      if (token == null) {
        ToastHelper.showError(
          context,
          'Your session has expired. Please log in again.',
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final body = {
        'sectionId': widget.sectionId,
        'questionText': questionText,
        'explanation': _hintController.text.trim(),
        'categoryId': _aiCategoryId,
        'skillParamId': _aiSkillId,
        'difficultyId': _aiDifficultyId,
        'options': payloadOptions,
      };

      final response = await http.post(
        Uri.parse('http://localhost:8080/api/v1/trainer/questions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final newId = resData['id'] as int;
        ToastHelper.showSuccess(context, 'Question created successfully!');
        widget.onQuestionCreated([newId]);
        Navigator.pop(context);
      } else {
        final errorMsg =
            jsonDecode(response.body)['error'] ?? 'Failed to save question';
        ToastHelper.showError(context, errorMsg);
      }
    } catch (e) {
      debugPrint('Error saving question: $e');
      ToastHelper.showError(context, 'Connection error. Please try again.');
    } finally {
      setState(() {
        _isSaving = false;
      });
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

    // Dispose editor option controllers
    _disposeEditorOptionsControllers();

    // legacy editor controllers disposed below

    if (kIsWeb) {
      unregisterDragDrop();
    }
    _questionController.dispose();
    _hintController.dispose();
    for (var opt in _options) {
      opt['textController'].dispose();
      opt['explanationController'].dispose();
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
                    // Question text field with formatting bar
                    const Text(
                      'Question *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          // Format bar
                          Container(
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                _buildFormatButton('B'),
                                _buildFormatButton('I'),
                                _buildFormatButton('1.'),
                                const SizedBox(width: 12),
                                _buildFormatIconButton(Icons.link),
                                _buildFormatButton('Σ'),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          // Field
                          TextField(
                            controller: _questionController,
                            minLines: 5,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: 'Enter your question here...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(
                                    text: '$_aiQuantity',
                                  ),
                                  enabled: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: TextEditingController(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final n = int.tryParse(v.trim());
                                    if (n == null) return;
                                    setState(() {
                                      _aiQuantity = n.clamp(1, 10);
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    hintText: '1..10',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildFormatButton(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatIconButton(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
        ),
      ),
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
                      // Clear extra correct options to keep single selection
                      int firstCorrectIdx = _options.indexWhere(
                        (opt) => opt['isCorrect'] == true,
                      );
                      if (firstCorrectIdx == -1 && _options.isNotEmpty) {
                        _options[0]['isCorrect'] = true;
                      } else {
                        for (int i = 0; i < _options.length; i++) {
                          _options[i]['isCorrect'] = (i == firstCorrectIdx);
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
      );

      final generated = resp.questions ?? [];
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
      _disposeEditorOptionsControllers();

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

      // Load first into editor
      _editingQuestionIndex = 0;
      _loadQuestionIntoEditor(_editingQuestionIndex);

      setState(() {});
      ToastHelper.showSuccess(
        context,
        'AI generated ${_singleQuestions.length} question(s).',
      );
    } catch (e) {
      debugPrint('Error generating by AI: $e');
      ToastHelper.showError(context, 'AI generate failed. Please try again.');
    } finally {
      setState(() {
        _isGeneratingByAi = false;
      });
    }
  }

  void _disposeEditorOptionsControllers() {
    // Do NOT dispose here because editor controllers are reused by the
    // underlying question model list in _singleQuestions.
    // We only detach references.
    _options.clear();
  }

  void _loadQuestionIntoEditor(int index) {
    if (index < 0 || index >= _singleQuestions.length) return;
    final q = _singleQuestions[index];

    _questionController.text =
        (q['questionTextController'] as TextEditingController).text;
    _hintController.text = (q['hintController'] as TextEditingController).text;

    _disposeEditorOptionsControllers();

    final opts = q['options'] as List<Map<String, dynamic>>;
    // clone controllers reference (we want edits to reflect on same controllers)
    for (final opt in opts) {
      _options.add({
        'textController': opt['textController'],
        'isCorrect': opt['isCorrect'],
        'explanationController': opt['explanationController'],
      });
    }

    setState(() {
      _editingQuestionIndex = index;
    });
  }

  void _syncEditorToModel() {
    if (_singleQuestions.isEmpty) return;
    final q = _singleQuestions[_editingQuestionIndex];
    (q['questionTextController'] as TextEditingController).text =
        _questionController.text;
    (q['hintController'] as TextEditingController).text = _hintController.text;

    final opts = q['options'] as List<Map<String, dynamic>>;
    for (int i = 0; i < opts.length; i++) {
      opts[i]['isCorrect'] = _options[i]['isCorrect'];
      (opts[i]['textController'] as TextEditingController).text =
          (_options[i]['textController'] as TextEditingController).text;
      (opts[i]['explanationController'] as TextEditingController).text =
          (_options[i]['explanationController'] as TextEditingController).text;
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

                  _editingQuestionIndex = _singleQuestions.length - 1;
                  _loadQuestionIntoEditor(_editingQuestionIndex);
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
              final bool isExpanded = setIdx == _editingQuestionIndex;
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
                  border: Border.all(
                    color: isExpanded
                        ? const Color(0xFF20B486)
                        : const Color(0xFFE2E8F0),
                    width: isExpanded ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _editingQuestionIndex = setIdx;
                          _loadQuestionIntoEditor(setIdx);
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isExpanded
                                    ? const Color(0xFF20B486)
                                    : const Color(0xFF1E293B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const Spacer(),
                            if (_singleQuestions.length > 1) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFEF4444),
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _singleQuestions.removeAt(setIdx);
                                    if (_singleQuestions.isEmpty) {
                                      _editingQuestionIndex = 0;
                                      _options.clear();
                                      _disposeEditorOptionsControllers();
                                    } else {
                                      _editingQuestionIndex =
                                          _editingQuestionIndex.clamp(
                                            0,
                                            _singleQuestions.length - 1,
                                          );
                                      _loadQuestionIntoEditor(
                                        _editingQuestionIndex,
                                      );
                                    }
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF64748B),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Options list - allow internal scroll to prevent overflow
                            SizedBox(
                              height: 360,
                              child: ListView.builder(
                                itemCount: opts.length,
                                itemBuilder: (context, optIdx) {
                                  final opt = opts[optIdx];
                                  final bool isCorrect =
                                      opt['isCorrect'] as bool;
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
                                        // Radio-like circle
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
                                                'Each question set must have at least one option.',
                                              );
                                              return;
                                            }
                                            setState(() {
                                              // Detach controllers; actual disposal is handled
                                              // when the owning question model list is disposed.
                                              // Do not call dispose() here.
                                              // (no-op)
                                              // ignore: unused_local_variable
                                              final _ = opt['textController'];
                                              // ignore: unused_local_variable
                                              final __ =
                                                  opt['explanationController'];
                                              opts.removeAt(optIdx);
                                              if (!opts.any(
                                                    (o) =>
                                                        o['isCorrect'] == true,
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

                            // Question text
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

                _editingQuestionIndex = _singleQuestions.length - 1;
                _loadQuestionIntoEditor(_editingQuestionIndex);
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
