import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import 'create_lesson_text_page.dart';
import 'create_quiz_page.dart';
import 'lesson_list_widget.dart';

class CreateLessonPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int selectedSectionIndex;
  final Future<void> Function(List<dynamic> updatedSections) onSectionsChanged;

  const CreateLessonPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.selectedSectionIndex,
    required this.onSectionsChanged,
  });

  @override
  State<CreateLessonPage> createState() => _CreateLessonPageState();
}

class _CreateLessonPageState extends State<CreateLessonPage> {
  late List<dynamic> _localSections;
  late int? _activeSectionIndex;
  final Set<int> _expandedIndices = {};
  bool _showTypeSelection = false;

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);
    _activeSectionIndex = widget.selectedSectionIndex;
    _expandedIndices.add(widget.selectedSectionIndex);
    if (_activeSectionIndex != null && _activeSectionIndex! < _localSections.length) {
      final lessons = _localSections[_activeSectionIndex!]['lessons'] as List<dynamic>? ?? [];
      _showTypeSelection = lessons.isEmpty;
    }
  }

  final _authService = AuthService();

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  Future<void> _refreshCourseDetail() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final uri = Uri.parse('$apiBaseUrl/courses/${widget.courseId}?t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint("REFRESH COURSE DETAIL RESPONSE: $data");
        setState(() {
          if (data['sessions'] != null) {
            _localSections = List.from(data['sessions']);
            debugPrint("UPDATED LOCAL SECTIONS: $_localSections");
          }
        });
      }
    } catch (e) {
      debugPrint('Error refreshing course details in CreateLessonPage: $e');
    }
  }

  Future<void> _notifyParent() async {
    await widget.onSectionsChanged(_localSections);
    await _refreshCourseDetail();
  }

  void _showAddLessonDialog(int sectionIndex, String type) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            type == 'quiz' ? 'Add Quiz' : 'Add Lesson',
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type == 'quiz' ? 'QUIZ TITLE *' : 'LESSON TITLE *',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: type == 'quiz' ? 'e.g. Grammar Quiz 1' : 'e.g. Nouns and Pronouns',
                  hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF20B486)),
                  ),
                ),
                autofocus: true,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    final lessons = List.from(_localSections[sectionIndex]['lessons'] ?? []);
                    lessons.add({
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'title': text,
                      'itemType': type,
                      'displayOrder': lessons.length + 1,
                    });
                    _localSections[sectionIndex]['lessons'] = lessons;
                    _showTypeSelection = false;
                  });
                   _notifyParent();
                   Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeSelectionContainer(List<dynamic> lessons) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF20B486).withAlpha(51), width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Select content type:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateLessonTextPage(
                          courseId: widget.courseId,
                          courseTitle: widget.courseTitle,
                          trainerName: widget.trainerName,
                          trainerInitials: widget.trainerInitials,
                          sections: _localSections,
                          sectionIndex: widget.selectedSectionIndex,
                          onSectionsChanged: (updatedSections) async {
                            setState(() {
                              _localSections = updatedSections;
                              _showTypeSelection = false;
                            });
                            await _notifyParent();
                          },
                        ),
                      ),
                    );
                    if (result == 'goToIntroduction' && mounted) {
                      if (context.mounted) {
                        Navigator.pop(context, 'goToIntroduction');
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6FFFA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF20B486),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Lesson',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Text',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateQuizPage(
                          courseId: widget.courseId,
                          courseTitle: widget.courseTitle,
                          trainerName: widget.trainerName,
                          trainerInitials: widget.trainerInitials,
                          sections: _localSections,
                          sectionIndex: widget.selectedSectionIndex,
                          onSectionsChanged: (updatedSections) async {
                            setState(() {
                              _localSections = updatedSections;
                              _showTypeSelection = false;
                            });
                            await _notifyParent();
                          },
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6FFFA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.help_outline,
                            color: Color(0xFF20B486),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Quiz',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Test',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _showTypeSelection = false;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.close, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Outfit',
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

  void _deleteLesson(int sectionIndex, int lessonIndex) async {
    setState(() {
      final lessons = List.from(_localSections[sectionIndex]['lessons'] ?? []);
      lessons.removeAt(lessonIndex);
      _localSections[sectionIndex]['lessons'] = lessons;
    });
    await _notifyParent();
  }

  void _showEditLessonDialog(int sectionIndex, int lessonIndex) {
    final lesson = _localSections[sectionIndex]['lessons'][lessonIndex];
    final titleController = TextEditingController(text: lesson['title']);
    String selectedType = lesson['itemType'] ?? 'video';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Edit Lesson',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LESSON TITLE *',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Nouns and Pronouns',
                      hintStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF20B486)),
                      ),
                    ),
                    autofocus: true,
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LESSON TYPE',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF20B486)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Video Lecture', style: TextStyle(fontFamily: 'Outfit', fontSize: 14))),
                      DropdownMenuItem(value: 'text', child: Text('Document/Reading', style: TextStyle(fontFamily: 'Outfit', fontSize: 14))),
                      DropdownMenuItem(value: 'quiz', child: Text('Quiz/Assessment', style: TextStyle(fontFamily: 'Outfit', fontSize: 14))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = titleController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        final lessons = List.from(_localSections[sectionIndex]['lessons'] ?? []);
                        lessons[lessonIndex] = {
                          ...lessons[lessonIndex],
                          'title': text,
                          'itemType': selectedType,
                        };
                        _localSections[sectionIndex]['lessons'] = lessons;
                      });
                      _notifyParent();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

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
                              _buildMainContentCard(),
                              const SizedBox(height: 24),
                              _buildActionsRow(),
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
                        _buildMainContentCard(),
                        const SizedBox(height: 24),
                        _buildActionsRow(),
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
              'Overall completion progress',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '33%',
              style: TextStyle(
                color: Color(0xFF20B486),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.33,
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
              Container(
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
                'Progress Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
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
                'Submit once 100% completed',
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

  Widget _buildMainContentCard() {
    if (_activeSectionIndex != null) {
      final section = _localSections[_activeSectionIndex!];
      final lessons = section['lessons'] as List<dynamic>? ?? [];
      debugPrint("BUILD MAIN CONTENT CARD: activeIndex = $_activeSectionIndex, section = $section, lessons length = ${lessons.length}, lessons = $lessons");
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    section['title'] ?? 'Untitled Section',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        // Handle edit section title if needed
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _localSections.removeAt(_activeSectionIndex!);
                          _activeSectionIndex = null;
                        });
                        _notifyParent();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFEFF2F5), height: 1),
            const SizedBox(height: 24),
            if (_showTypeSelection) ...[
              _buildTypeSelectionContainer(lessons),
            ] else ...[
              LessonListWidget(
                lessons: lessons,
                onAddLessonPressed: () {
                  setState(() {
                    _showTypeSelection = true;
                  });
                },
                onEditLessonPressed: (lessonIndex) {
                  final lesson = lessons[lessonIndex];
                  if (lesson['itemType'] == 'quiz') {
                    _showEditLessonDialog(_activeSectionIndex!, lessonIndex);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateLessonTextPage(
                          courseId: widget.courseId,
                          courseTitle: widget.courseTitle,
                          trainerName: widget.trainerName,
                          trainerInitials: widget.trainerInitials,
                          sections: _localSections,
                          sectionIndex: _activeSectionIndex!,
                          onSectionsChanged: (updatedSections) async {
                            setState(() {
                              _localSections = updatedSections;
                            });
                            await _notifyParent();
                          },
                          lessonIndex: lessonIndex,
                        ),
                      ),
                    );
                  }
                },
                onDeleteLessonPressed: (lessonIndex) {
                  _deleteLesson(_activeSectionIndex!, lessonIndex);
                },
              ),
            ],
          ],
        ),
      );
    }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Course Content',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_localSections.length} ${_localSections.length == 1 ? "chapter" : "chapters"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Go back to sections creation
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
                label: const Text(
                  'New Section',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                    color: Color(0xFF20B486),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6FFFA),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionsList(),
        ],
      ),
    );
  }

  Widget _buildSectionsList() {
    return CustomPaint(
      painter: DashedRoundedBorderPainter(
        color: const Color(0xFFCBD5E1),
        borderRadius: 12,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _localSections.length,
          itemBuilder: (context, index) {
            final section = _localSections[index];
            final lessons = section['lessons'] as List<dynamic>? ?? [];
            final isExpanded = _expandedIndices.contains(index);

            final sectionCard = Container(
              margin: EdgeInsets.only(bottom: index == _localSections.length - 1 ? 0 : 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF5FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Circle Index Badge
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD0E7FF),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0369A1),
                              fontFamily: 'Outfit',
                            ),
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
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                          onPressed: () {
                            setState(() {
                              _activeSectionIndex = index;
                              _expandedIndices.add(index);
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                          onPressed: () {
                            setState(() {
                              _localSections.removeAt(index);
                              if (_activeSectionIndex == index) {
                                _activeSectionIndex = null;
                              }
                            });
                            _notifyParent();
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: const Color(0xFF64748B),
                            size: 22,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_expandedIndices.contains(index)) {
                                _expandedIndices.remove(index);
                              } else {
                                _expandedIndices.add(index);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isExpanded) ...[
                    const Divider(color: Color(0xFFD0E7FF), height: 1),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: const Color(0xFF20B486).withAlpha(51),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (section['description'] != null && section['description'].toString().isNotEmpty) ...[
                            Text(
                              section['description'],
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                                fontFamily: 'Outfit',
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (lessons.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No lessons in this section yet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF94A3B8),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: lessons.length,
                              itemBuilder: (context, lessonIndex) {
                                final lesson = lessons[lessonIndex];
                                final itemType = lesson['itemType'] ?? 'video';
                                IconData lessonIcon = Icons.play_circle_outline;
                                String typeBadge = 'VIDEO';
                                
                                if (itemType == 'quiz' || itemType == 'practice') {
                                  lessonIcon = Icons.assignment_outlined;
                                  typeBadge = 'QUIZ';
                                } else if (itemType == 'document' || itemType == 'text') {
                                  lessonIcon = Icons.description_outlined;
                                  typeBadge = 'TEXT';
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Leftmost solid green strip
                                          Container(
                                            width: 4,
                                            color: const Color(0xFF20B486),
                                          ),
                                          const SizedBox(width: 16),
                                          // Leftmost icon in rounded circle
                                          Center(
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE6FFFA),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(lessonIcon, color: const Color(0xFF20B486), size: 18),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Title, Badge and Description
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        lesson['title'] ?? 'Untitled Lesson',
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF1E293B),
                                                          fontFamily: 'Outfit',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Badge
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          typeBadge,
                                                          style: const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF475569),
                                                            fontFamily: 'Outfit',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (lesson['description'] != null && lesson['description'].toString().trim().isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      lesson['description'],
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF64748B),
                                                        fontFamily: 'Outfit',
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Action buttons
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 18),
                                                tooltip: 'Edit Lesson',
                                                onPressed: () => _showEditLessonDialog(index, lessonIndex),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                                tooltip: 'Delete Lesson',
                                                onPressed: () => _deleteLesson(index, lessonIndex),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );

            if (isExpanded && _activeSectionIndex == index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF20B486).withAlpha(77), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(32, 180, 134, 0.05),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select content type:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateLessonTextPage(
                                        courseId: widget.courseId,
                                        courseTitle: widget.courseTitle,
                                        trainerName: widget.trainerName,
                                        trainerInitials: widget.trainerInitials,
                                        sections: _localSections,
                                        sectionIndex: index,
                                        onSectionsChanged: (updatedSections) async {
                                          setState(() {
                                            _localSections = updatedSections;
                                          });
                                          await _notifyParent();
                                        },
                                      ),
                                    ),
                                  );
                                  if (result == 'goToIntroduction' && context.mounted) {
                                    Navigator.pop(context, 'goToIntroduction');
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6FFFA),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.description_outlined,
                                          color: Color(0xFF20B486),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Lesson',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Text',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showAddLessonDialog(index, 'quiz'),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6FFFA),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.help_outline,
                                          color: Color(0xFF20B486),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Quiz',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Test',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _activeSectionIndex = null;
                              });
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  sectionCard,
                ],
              );
            }

            return sectionCard;
          },
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        const Text(
          'Last saved: Just now',
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
          onPressed: () {
            _notifyParent();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Save',
            style: TextStyle(
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
