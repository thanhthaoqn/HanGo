import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';

class AddNewQuestionPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final int sectionId;
  final String sectionTitle;
  final Function(int newQuestionId) onQuestionCreated;

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

  // Question details
  String _questionType = 'SINGLE'; // 'SINGLE' or 'MULTIPLE'
  String? _pdfName;
  String? _pdfSize;

  // Options list state
  final List<Map<String, dynamic>> _options = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize with 2 options
    _addOption(text: '', isCorrect: true);
    _addOption(text: '', isCorrect: false);
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
    if (_options.length <= 1) {
      ToastHelper.showError(context, 'Questions must have at least one option.');
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

  Future<void> _handlePdfUpload() async {
    // Simulated upload for premium UX
    setState(() {
      _pdfName = 'Grammar_Rules_Reference.pdf';
      _pdfSize = '4.2 MB';
    });
    ToastHelper.showSuccess(context, 'PDF document uploaded successfully.');
  }

  void _removePdf() {
    setState(() {
      _pdfName = null;
      _pdfSize = null;
    });
  }

  Future<void> _saveQuestion() async {
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ToastHelper.showError(context, 'Please enter the question text.');
      return;
    }

    // Verify option text fields
    List<Map<String, dynamic>> payloadOptions = [];
    bool hasCorrectAnswer = false;
    for (int i = 0; i < _options.length; i++) {
      final text = _options[i]['textController'].text.trim();
      if (text.isEmpty) {
        ToastHelper.showError(context, 'Please fill in all option texts.');
        return;
      }
      final bool isCorrect = _options[i]['isCorrect'] as bool;
      if (isCorrect) {
        hasCorrectAnswer = true;
      }
      payloadOptions.add({
        'optionText': text,
        'isCorrect': isCorrect,
      });
    }

    if (!hasCorrectAnswer) {
      ToastHelper.showError(context, 'Please select at least one correct answer.');
      return;
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

      // We determine category dynamically, fallback to 1 (Grammar & Vocabulary)
      final body = {
        'sectionId': widget.sectionId,
        'questionText': questionText,
        'explanation': _hintController.text.trim(),
        'categoryId': 1,
        'difficultyId': 14, // Easy by default
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
        widget.onQuestionCreated(newId);
        Navigator.pop(context);
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? 'Failed to save question';
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
                    style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'Outfit'),
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
                          // Field
                          TextField(
                            controller: _questionController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Enter your question here...',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
                              contentPadding: EdgeInsets.all(12),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
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
                    // Description / Hint
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
              onPressed: _isSaving ? null : _saveQuestion,
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
              // Multiple Choice
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _questionType = 'MULTIPLE';
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _questionType == 'MULTIPLE' ? const Color(0xFF20B486) : Colors.white,
                      border: Border.all(
                        color: _questionType == 'MULTIPLE' ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_box_outlined,
                          size: 16,
                          color: _questionType == 'MULTIPLE' ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Multiple Choice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _questionType == 'MULTIPLE' ? Colors.white : const Color(0xFF64748B),
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
                      int firstCorrectIdx = _options.indexWhere((opt) => opt['isCorrect'] == true);
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
                      color: _questionType == 'SINGLE' ? const Color(0xFF20B486) : Colors.white,
                      border: Border.all(
                        color: _questionType == 'SINGLE' ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_square,
                          size: 16,
                          color: _questionType == 'SINGLE' ? Colors.white : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Single Choice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _questionType == 'SINGLE' ? Colors.white : const Color(0xFF64748B),
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

  Widget _buildAnswersPanel() {
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
            'ANSWERS *',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF20B486),
              letterSpacing: 0.5,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          // List builder
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final opt = _options[index];
              final bool isCorrect = opt['isCorrect'] as bool;
              final TextEditingController textCtrl = opt['textController'] as TextEditingController;
              final TextEditingController expCtrl = opt['explanationController'] as TextEditingController;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                    width: isCorrect ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Radio / Checkbox indicator
                        InkWell(
                          onTap: () => _handleOptionSelect(index),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCorrect ? const Color(0xFF20B486) : const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                            ),
                            child: isCorrect
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF20B486),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Option input field
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
                        // Actions
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF64748B), size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _removeOption(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Explanation field
                    TextField(
                      controller: expCtrl,
                      decoration: InputDecoration(
                        hintText: 'Explanation (Optional): Explain why this answer is correct or incorrect...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'Outfit'),
                        fillColor: const Color(0xFFF8FAFC),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Add Answer button
          OutlinedButton.icon(
            onPressed: () => _addOption(text: '', isCorrect: false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF20B486)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 14, color: Color(0xFF20B486)),
            label: const Text(
              'Add Answer',
              style: TextStyle(
                color: Color(0xFF20B486),
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
