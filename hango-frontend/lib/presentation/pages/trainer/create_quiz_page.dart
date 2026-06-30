import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'select_quiz_questions_page.dart';


class CreateQuizPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final Future<void> Function(List<dynamic> updatedSections) onSectionsChanged;

  const CreateQuizPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.sectionIndex,
    required this.onSectionsChanged,
  });

  @override
  State<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends State<CreateQuizPage> {
  late List<dynamic> _localSections;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _passingScoreController = TextEditingController();
  final TextEditingController _timeLimitController = TextEditingController();
  final TextEditingController _versionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _passingScoreController.dispose();
    _timeLimitController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _notifyParent() async {
    await widget.onSectionsChanged(_localSections);
  }

  void _onCreateQuizPressed() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ToastHelper.showError(context, 'Please enter a quiz title');
      return;
    }

    setState(() {
      final lessons = List.from(_localSections[widget.sectionIndex]['lessons'] ?? []);
      lessons.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': title,
        'itemType': 'quiz',
        'displayOrder': lessons.length + 1,
        'description': _descController.text.trim(),
        'passingScore': int.tryParse(_passingScoreController.text.trim()) ?? 70,
        'timeLimit': int.tryParse(_timeLimitController.text.trim()) ?? 60,
        'version': _versionController.text.trim(),
      });
      _localSections[widget.sectionIndex]['lessons'] = lessons;
    });

    final _authService = AuthService();
    
    // 1. Notify parent (saves the course including this new quiz lesson to backend)
    await _notifyParent();
    if (!mounted) return;
    
    // 2. Fetch updated course details to discover the database ID assigned to our new quiz
    try {
      final token = await _authService.getToken();
      if (token == null) {
        ToastHelper.showError(context, 'Authentication required');
        return;
      }
      
      String baseUrl = 'http://localhost:8080/api/v1';
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        baseUrl = 'http://10.0.2.2:8080/api/v1';
      }

      final uri = Uri.parse('$baseUrl/courses/${widget.courseId}?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final updatedSections = data['sessions'] as List<dynamic>;
        
        // Find the quiz lesson in updatedSections by title
        dynamic newQuizLesson;
        for (var section in updatedSections) {
          final lessons = section['lessons'] as List<dynamic>? ?? [];
          for (var lesson in lessons) {
            if (lesson['itemType'] == 'quiz' && lesson['title'] == title) {
              newQuizLesson = lesson;
              break;
            }
          }
        }
        
        if (newQuizLesson != null) {
          final newQuizId = newQuizLesson['id'] as int;
          ToastHelper.showSuccess(context, 'Quiz created successfully');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SelectQuizQuestionsPage(
                courseId: widget.courseId,
                courseTitle: widget.courseTitle,
                trainerName: widget.trainerName,
                trainerInitials: widget.trainerInitials,
                sections: updatedSections,
                sectionIndex: widget.sectionIndex,
                lessonId: newQuizId,
                onSectionsChanged: widget.onSectionsChanged,
              ),
            ),
          );
        } else {
          ToastHelper.showError(context, 'Failed to find created quiz database ID');
          Navigator.pop(context);
        }
      } else {
        ToastHelper.showError(context, 'Failed to sync quiz with server');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error syncing created quiz details: $e');
      ToastHelper.showError(context, 'Sync error: $e');
      Navigator.pop(context);
    }
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
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 24),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: _buildLeftPanel(context)),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildMainFormCard(section),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLeftPanel(context),
                        const SizedBox(height: 24),
                        _buildMainFormCard(section),
                      ],
                    ),
                ],
              ),
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
                'Create New Quiz',
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
        Row(
          children: [
            const Text(
              'OVERALL COMPLETION PROGRESS',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '68%',
              style: TextStyle(
                color: Color(0xFF20B486),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.68,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF20B486)),
                ),
              ),
            ),
          ],
        )
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
              // Step 1: Introduction
              InkWell(
                onTap: () {
                  Navigator.pop(context, 'goToIntroduction');
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFEFF2F5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF20B486),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Introduction',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 11,
                              color: activeColor,
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
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFEFF2F5)),
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
                          color: activeColor,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Syllabus',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Progress Overview
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PROGRESS OVERVIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1/3 steps completed successfully. Complete the remaining steps to publish the course.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text(
                  'Submit for Review',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B486).withAlpha(102),
                  disabledBackgroundColor: const Color(0xFF20B486).withAlpha(102),
                  disabledForegroundColor: Colors.white.withAlpha(200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'submit once 100% completed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontFamily: 'Outfit',
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainFormCard(dynamic section) {
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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title & Icon Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Create New Quiz',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F9F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  color: Color(0xFF20B486),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // QUIZ TITLE
          const Text(
            'QUIZ TITLE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter quiz title...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),

          // QUIZ DESCRIPTION
          const Text(
            'QUIZ DESCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Briefly describe what this quiz covers...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
              contentPadding: const EdgeInsets.all(16),
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
            style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),

          // PASSING SCORE & TIME LIMIT ROW
          Row(
            children: [
              // PASSING SCORE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PASSING SCORE (%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passingScoreController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter pass score...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Text(
                            '%',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // TIME LIMIT
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TIME LIMIT (MINUTES)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _timeLimitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter time...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Text(
                            'min',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // VERSION
          const Text(
            'VERSION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _versionController,
            decoration: InputDecoration(
              hintText: 'Enter version...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                onSelected: (value) {
                  _versionController.text = value;
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'v1.0', child: Text('v1.0', style: TextStyle(fontFamily: 'Outfit'))),
                  const PopupMenuItem(value: 'v2.0', child: Text('v2.0', style: TextStyle(fontFamily: 'Outfit'))),
                  const PopupMenuItem(value: 'v3.0', child: Text('v3.0', style: TextStyle(fontFamily: 'Outfit'))),
                ],
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
                borderSide: const BorderSide(color: Color(0xFF20B486)),
              ),
            ),
            style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 32),

          // ACTIONS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _onCreateQuizPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B486),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Create Quiz',
                  style: TextStyle(
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
}
