import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'add_new_question_page.dart';

class AddMultipleChoiceQuestionPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final int sectionId;
  final String sectionTitle;
  final Function(List<int> newQuestionIds) onQuestionCreated;

  const AddMultipleChoiceQuestionPage({
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
  State<AddMultipleChoiceQuestionPage> createState() => _AddMultipleChoiceQuestionPageState();
}

class _AddMultipleChoiceQuestionPageState extends State<AddMultipleChoiceQuestionPage> {
  final AuthService _authService = AuthService();

  // Text inputs
  final TextEditingController _passageController = TextEditingController(
    text: ""
  );
  final TextEditingController _hintController = TextEditingController();

  String? _pdfName;
  String? _pdfSize;

  // Answer sets for sub-questions
  final List<Map<String, dynamic>> _answerSets = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with 2 empty answer sets matching mockup
    _addAnswerSet(
      questionText: 'Question 1',
      optionsData: [
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': true},
      ],
      explanation: '',
      isExpanded: true,
    );

    _addAnswerSet(
      questionText: 'Question 2',
      optionsData: [
        {'text': '', 'isCorrect': true},
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': false},
      ],
      explanation: '',
      isExpanded: true,
    );
  }

  void _addAnswerSet({
    required String questionText,
    required List<Map<String, dynamic>> optionsData,
    String explanation = '',
    bool isExpanded = false,
  }) {
    final expCtrl = TextEditingController(text: explanation);
    final List<Map<String, dynamic>> options = [];

    for (var opt in optionsData) {
      options.add({
        'textController': TextEditingController(text: opt['text']),
        'isCorrect': opt['isCorrect'],
      });
    }

    setState(() {
      _answerSets.add({
        'questionText': questionText,
        'isExpanded': isExpanded,
        'explanationController': expCtrl,
        'options': options,
      });
    });
  }

  void _addNewAnswerSetClick() {
    int nextNum = _answerSets.length + 1;
    _addAnswerSet(
      questionText: 'Question $nextNum',
      optionsData: [
        {'text': '', 'isCorrect': true},
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': false},
        {'text': '', 'isCorrect': false},
      ],
      explanation: '',
      isExpanded: true,
    );
    // Collapse others
    setState(() {
      for (int i = 0; i < _answerSets.length - 1; i++) {
        _answerSets[i]['isExpanded'] = false;
      }
    });
  }

  void _removeAnswerSet(int index) {
    setState(() {
      final set = _answerSets[index];
      set['explanationController'].dispose();
      final options = set['options'] as List<Map<String, dynamic>>;
      for (var opt in options) {
        opt['textController'].dispose();
      }
      _answerSets.removeAt(index);
      // Normalize titles
      for (int i = 0; i < _answerSets.length; i++) {
        _answerSets[i]['questionText'] = 'Question ${i + 1}';
      }
    });
  }

  void _addOptionToSet(int setIndex) {
    setState(() {
      final options = _answerSets[setIndex]['options'] as List<Map<String, dynamic>>;
      options.add({
        'textController': TextEditingController(),
        'isCorrect': false,
      });
    });
  }

  void _removeOptionFromSet(int setIndex, int optionIndex) {
    final options = _answerSets[setIndex]['options'] as List<Map<String, dynamic>>;
    if (options.length <= 1) {
      ToastHelper.showError(context, 'Each question set must have at least one option.');
      return;
    }
    setState(() {
      options[optionIndex]['textController'].dispose();
      options.removeAt(optionIndex);
    });
  }

  void _handleOptionSelect(int setIndex, int optionIndex) {
    setState(() {
      final options = _answerSets[setIndex]['options'] as List<Map<String, dynamic>>;
      // Single choice per sub-question set
      for (int i = 0; i < options.length; i++) {
        options[i]['isCorrect'] = (i == optionIndex);
      }
    });
  }

  Future<void> _handlePdfUpload() async {
    setState(() {
      _pdfName = 'Vietnam_Art_Exhibition_Doc.pdf';
      _pdfSize = '5.8 MB';
    });
    ToastHelper.showSuccess(context, 'PDF document uploaded successfully.');
  }

  void _removePdf() {
    setState(() {
      _pdfName = null;
      _pdfSize = null;
    });
  }

  Future<void> _saveGroupQuestion() async {
    final passageText = _passageController.text.trim();
    if (passageText.isEmpty) {
      ToastHelper.showError(context, 'Please enter the passage text.');
      return;
    }

    if (_answerSets.isEmpty) {
      ToastHelper.showError(context, 'Please add at least one answer set.');
      return;
    }

    List<Map<String, dynamic>> payloadSubQuestions = [];
    for (int i = 0; i < _answerSets.length; i++) {
      final set = _answerSets[i];
      final label = set['questionText'] as String;
      final exp = set['explanationController'].text.trim();
      final options = set['options'] as List<Map<String, dynamic>>;

      List<Map<String, dynamic>> payloadOptions = [];
      bool hasCorrectAnswer = false;
      for (int j = 0; j < options.length; j++) {
        final text = options[j]['textController'].text.trim();
        if (text.isEmpty) {
          ToastHelper.showError(context, 'Please fill in all option texts for $label.');
          return;
        }
        final bool isCorrect = options[j]['isCorrect'] as bool;
        if (isCorrect) {
          hasCorrectAnswer = true;
        }
        payloadOptions.add({
          'optionText': text,
          'isCorrect': isCorrect,
        });
      }

      if (!hasCorrectAnswer) {
        ToastHelper.showError(context, 'Please select a correct answer for $label.');
        return;
      }

      payloadSubQuestions.add({
        'questionText': label,
        'explanation': exp,
        'options': payloadOptions,
      });
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        ToastHelper.showError(context, 'Your session has expired. Please log in again.');
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final body = {
        'sectionId': widget.sectionId,
        'passageText': passageText,
        'explanation': _hintController.text.trim(),
        'categoryId': 1,
        'difficultyId': 14,
        'subQuestions': payloadSubQuestions,
      };

      final response = await http.post(
        Uri.parse('http://localhost:8080/api/v1/trainer/questions/group'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final List<dynamic> idsList = resData['questionIds'] as List<dynamic>? ?? [];
        final List<int> questionIds = idsList.map((id) => id as int).toList();
        ToastHelper.showSuccess(context, 'Group question created successfully!');
        widget.onQuestionCreated(questionIds);
        Navigator.pop(context);
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? 'Failed to save group question';
        ToastHelper.showError(context, errorMsg);
      }
    } catch (e) {
      debugPrint('Error saving group question: $e');
      ToastHelper.showError(context, 'Connection error. Please try again.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _passageController.dispose();
    _hintController.dispose();
    for (var set in _answerSets) {
      set['explanationController'].dispose();
      final options = set['options'] as List<Map<String, dynamic>>;
      for (var opt in options) {
        opt['textController'].dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Top Header Row
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
            icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF4B5563), size: 24),
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
                  child: Container(
                    width: 4,
                    color: const Color(0xFF20B486),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.send_outlined, size: 14),
                  label: const Text(
                    'Submit for Review',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Outfit'),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'submit once 100% completed',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
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
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'Outfit'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Passage Text & PDF
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
                          Container(
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          TextField(
                            controller: _passageController,
                            maxLines: 12,
                            decoration: const InputDecoration(
                              hintText: 'Enter your passage here...',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.5, fontFamily: 'Outfit'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    _pdfName != null
                        ? _buildPdfAttachedCard()
                        : InkWell(
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
                                  Icon(Icons.picture_as_pdf_outlined, size: 28, color: Color(0xFF64748B)),
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
                    const Text(
                      'Description / Hint (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _hintController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add a hint to help students...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
                        contentPadding: const EdgeInsets.all(12),
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
                          borderSide: const BorderSide(color: Color(0xFF20B486), width: 1.5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Question Type & Answer Details dropdowns
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildQuestionTypeSelector(),
                  const SizedBox(height: 24),
                  _buildAnswerDetailsPanel(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Divider(height: 1, color: Color(0xFFEFF2F5)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              onPressed: _isSaving ? null : _saveGroupQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
          child: Icon(
            icon,
            size: 14,
            color: const Color(0xFF64748B),
          ),
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
                  _pdfName!,
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
                Text(
                  _pdfSize!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
            onPressed: _removePdf,
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
              // Multiple Choice (active)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20B486),
                    border: Border.all(color: const Color(0xFF20B486)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_box_outlined, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Multiple Choice',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Single Choice (goes back to AddNewQuestionPage)
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddNewQuestionPage(
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
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_square, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          'Single Choice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
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

  Widget _buildAnswerDetailsPanel() {
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
          // Sub-questions sets
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _answerSets.length,
            itemBuilder: (context, setIdx) {
              final set = _answerSets[setIdx];
              final bool isExpanded = set['isExpanded'] as bool;
              final String title = set['questionText'] as String;
              final options = set['options'] as List<Map<String, dynamic>>;
              final TextEditingController expCtrl = set['explanationController'] as TextEditingController;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isExpanded ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                    width: isExpanded ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Expand/Collapse Header Row
                    InkWell(
                      onTap: () {
                        setState(() {
                          _answerSets[setIdx]['isExpanded'] = !isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isExpanded ? const Color(0xFF20B486) : const Color(0xFF1E293B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const Spacer(),
                            if (_answerSets.length > 1) ...[
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                                onPressed: () => _removeAnswerSet(setIdx),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
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
                            // Options builder for this question set
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: options.length,
                              itemBuilder: (context, optIdx) {
                                final opt = options[optIdx];
                                final bool isCorrect = opt['isCorrect'] as bool;
                                final textCtrl = opt['textController'] as TextEditingController;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isCorrect ? const Color(0xFFE2F9F3) : Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCorrect ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                                      width: isCorrect ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Choice circular radio button
                                      InkWell(
                                        onTap: () => _handleOptionSelect(setIdx, optIdx),
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: isCorrect ? const Color(0xFF20B486) : Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isCorrect ? const Color(0xFF20B486) : const Color(0xFFCBD5E1),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: textCtrl,
                                          decoration: const InputDecoration(
                                            hintText: 'Enter option text...',
                                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
                                        ),
                                      ),
                                      if (isCorrect) ...[
                                        const Icon(Icons.check_circle, color: Color(0xFF20B486), size: 18),
                                        const SizedBox(width: 8),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                        onPressed: () => _removeOptionFromSet(setIdx, optIdx),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Add option to set button
                            TextButton.icon(
                              onPressed: () => _addOptionToSet(setIdx),
                              icon: const Icon(Icons.add, size: 14, color: Color(0xFF20B486)),
                              label: const Text(
                                'Add Option',
                                style: TextStyle(color: Color(0xFF20B486), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
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
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Explain why this correct answer is selected...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'Outfit'),
                                fillColor: const Color(0xFFF8FAFC),
                                filled: true,
                                contentPadding: const EdgeInsets.all(10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: const BorderSide(color: Color(0xFF20B486), width: 1),
                                ),
                              ),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4, fontFamily: 'Outfit'),
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
          // Add Answer Set Button
          OutlinedButton.icon(
            onPressed: _addNewAnswerSetClick,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 14, color: Color(0xFF475569)),
            label: const Text(
              'Add Answer Set',
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
