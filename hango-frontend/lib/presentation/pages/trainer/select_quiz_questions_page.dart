import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'add_new_question_page.dart';

class SelectQuizQuestionsPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final int lessonId; // Database ID of the newly created quiz lesson
  final Future<void> Function(List<dynamic> updatedSections) onSectionsChanged;

  const SelectQuizQuestionsPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.sectionIndex,
    required this.lessonId,
    required this.onSectionsChanged,
  });

  @override
  State<SelectQuizQuestionsPage> createState() => _SelectQuizQuestionsPageState();
}

class _SelectQuizQuestionsPageState extends State<SelectQuizQuestionsPage> {
  final _authService = AuthService();
  
  // State
  List<dynamic> _backendSections = [];
  bool _isLoadingSections = true;
  
  int? _currentSectionId;
  String _currentSectionTitle = '';
  
  List<dynamic> _questions = [];
  bool _isLoadingQuestions = false;
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  final int _pageSize = 5;
  String _searchQuery = '';
  
  final Set<int> _selectedQuestionIds = {};
  
  // Select by quantity state
  final TextEditingController _quantityController = TextEditingController(text: '10');
  String _quantityMode = 'START'; // START or RANDOM
  
  // Section quantities map
  final Map<int, int> _sectionQuantities = {};
  
  // Search controller
  final TextEditingController _searchController = TextEditingController();

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  @override
  void initState() {
    super.initState();
    _loadCourseSections();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Load Course Sections with Question Bank Count
  Future<void> _loadCourseSections() async {
    setState(() {
      _isLoadingSections = true;
    });
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final uri = Uri.parse('$apiBaseUrl/trainer/courses/${widget.courseId}/sections');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        setState(() {
          _backendSections = data;
          _isLoadingSections = false;
          
          // Set active section as the one currently selected in creator mode
          if (_backendSections.isNotEmpty) {
            int targetIdx = widget.sectionIndex;
            if (targetIdx >= _backendSections.length) {
              targetIdx = 0;
            }
            _currentSectionId = _backendSections[targetIdx]['id'] as int;
            _currentSectionTitle = _backendSections[targetIdx]['title'] as String;
            
            // Initialize quantity map to 0
            for (var sec in _backendSections) {
              _sectionQuantities[sec['id'] as int] = 0;
            }
          }
        });

        if (_currentSectionId != null) {
          _loadSectionQuestions(0);
        }
      } else {
        ToastHelper.showError(context, 'Failed to load course sections');
      }
    } catch (e) {
      debugPrint('Error loading course sections: $e');
      ToastHelper.showError(context, 'Connection error');
    }
  }

  // Load Paginated Questions in Current Section
  Future<void> _loadSectionQuestions(int page, {String search = ''}) async {
    if (_currentSectionId == null) return;
    setState(() {
      _isLoadingQuestions = true;
      _currentPage = page;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final searchParam = search.isNotEmpty ? '&search=${Uri.encodeComponent(search)}' : '';
      final uri = Uri.parse(
        '$apiBaseUrl/trainer/sections/$_currentSectionId/questions?page=$page&size=$_pageSize$searchParam',
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _questions = data['content'] as List<dynamic>;
          _totalPages = data['totalPages'] as int;
          _totalElements = data['totalElements'] as int;
          _isLoadingQuestions = false;
        });
      } else {
        ToastHelper.showError(context, 'Failed to load questions');
        setState(() {
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  // Quick Select by Quantity (START or RANDOM) for current Section
  Future<void> _selectByQuantity(int quantity, String mode) async {
    if (_currentSectionId == null) return;
    
    setState(() {
      _isLoadingQuestions = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final uri = Uri.parse(
        '$apiBaseUrl/trainer/sections/$_currentSectionId/questions/select?quantity=$quantity&mode=$mode',
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final ids = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          // Add newly selected questions to the set
          for (var id in ids) {
            _selectedQuestionIds.add(id as int);
          }
          _isLoadingQuestions = false;
        });
        ToastHelper.showSuccess(context, 'Selected $quantity questions from current section');
      } else {
        ToastHelper.showError(context, 'Failed to select questions');
        setState(() {
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      debugPrint('Error selecting questions: $e');
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  // Apply select-by-chapter quantities to all chapters
  Future<void> _applyAllChaptersSelection() async {
    final token = await _authService.getToken();
    if (token == null) return;

    List<int> sectionsToSelect = [];
    
    _sectionQuantities.forEach((secId, qty) {
      if (qty > 0) {
        sectionsToSelect.add(secId);
      }
    });

    if (sectionsToSelect.isEmpty) {
      ToastHelper.showError(context, 'Please specify quantities to select first');
      return;
    }

    setState(() {
      _isLoadingQuestions = true;
    });

    try {
      for (var secId in sectionsToSelect) {
        final qty = _sectionQuantities[secId]!;
        final uri = Uri.parse(
          '$apiBaseUrl/trainer/sections/$secId/questions/select?quantity=$qty&mode=$_quantityMode',
        );
        
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final ids = jsonDecode(response.body) as List<dynamic>;
          setState(() {
            for (var id in ids) {
              _selectedQuestionIds.add(id as int);
            }
          });
        }
      }
      
      ToastHelper.showSuccess(context, 'Applied chapter selection. Total questions selected: ${_selectedQuestionIds.length}');
      setState(() {
        _isLoadingQuestions = false;
      });
      // Refresh current page
      _loadSectionQuestions(_currentPage, search: _searchQuery);
    } catch (e) {
      debugPrint('Error applying chapter selections: $e');
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  // Save selected questions to backend and return to course management page
  Future<void> _saveSelectedQuestions() async {
    if (_selectedQuestionIds.isEmpty) {
      ToastHelper.showError(context, 'Please select at least one question');
      return;
    }

    setState(() {
      _isLoadingQuestions = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final uri = Uri.parse('$apiBaseUrl/trainer/lessons/${widget.lessonId}/questions');
      final body = jsonEncode({
        'questionIds': _selectedQuestionIds.toList(),
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ToastHelper.showSuccess(context, 'Quiz questions updated successfully');
        
        // Notify Parent of the new list state, then pop back
        await widget.onSectionsChanged(widget.sections);
        
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        ToastHelper.showError(context, 'Failed to save questions');
        setState(() {
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      debugPrint('Error saving questions: $e');
      setState(() {
        _isLoadingQuestions = false;
      });
    }
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
                              _buildSelectionPanel(),
                              const SizedBox(height: 24),
                              _buildQuestionListPanel(),
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
                        _buildSelectionPanel(),
                        const SizedBox(height: 24),
                        _buildQuestionListPanel(),
                      ],
                    ),
                  const SizedBox(height: 80), // Space for bottom persistent bar
                ],
              ),
            ),
          ),
          _buildBottomPersistentBar(),
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
              Container(
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

  Widget _buildSelectionPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basic Selection
          const Text(
            'BASIC SELECTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      for (var q in _questions) {
                        _selectedQuestionIds.add(q['id'] as int);
                      }
                    });
                    ToastHelper.showSuccess(context, 'Selected all visible questions');
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    'Select All (${_questions.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF20B486),
                    side: const BorderSide(color: Color(0xFF20B486)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      for (var q in _questions) {
                        _selectedQuestionIds.remove(q['id'] as int);
                      }
                    });
                    ToastHelper.showSuccess(context, 'Deselected visible questions');
                  },
                  icon: const Icon(Icons.highlight_off, size: 18),
                  label: const Text(
                    'Deselect All',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Select by Quantity
          const Text(
            'SELECT BY QUANTITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Numbers Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [5, 10, 15, 20, 25].map((val) {
              final isCurrent = _quantityController.text == val.toString();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _quantityController.text = val.toString();
                      });
                    },
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFFE2F9F3) : Colors.white,
                        border: Border.all(
                          color: isCurrent ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                          width: isCurrent ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        val.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? const Color(0xFF20B486) : const Color(0xFF475569),
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Input & Mode selection row
          Row(
            children: [
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'questions selected using',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Outfit'),
              ),
              const Spacer(),
              // Mode Toggles (From Start / Random)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildModeButton('From Start', 'START', Icons.playlist_add_check),
                    _buildModeButton('Random', 'RANDOM', Icons.shuffle),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Select by Chapter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SELECT BY CHAPTER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: _applyAllChaptersSelection,
                child: Row(
                  children: [
                    const Icon(Icons.done_all, size: 16, color: Color(0xFF20B486)),
                    const SizedBox(width: 4),
                    const Text(
                      'Apply All',
                      style: TextStyle(
                        color: Color(0xFF20B486),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sections List with Quantity Dropdowns
          _isLoadingSections
              ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              : Column(
                  children: _backendSections.map((sec) {
                    final int secId = sec['id'] as int;
                    final int qCount = sec['questionCount'] as int;
                    final isCurrent = _currentSectionId == secId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFFF0FDF4) : Colors.white,
                        border: Border.all(
                          color: isCurrent ? const Color(0xFF20B486).withAlpha(102) : const Color(0xFFE2E8F0),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _currentSectionId = secId;
                                  _currentSectionTitle = sec['title'] as String;
                                  _currentPage = 0;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                                _loadSectionQuestions(0);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sec['title'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrent ? const Color(0xFF20B486) : const Color(0xFF1E293B),
                                      fontSize: 13.5,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$qCount Questions total',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Qns selector input box with dropdown arrow style
                          Container(
                            width: 90,
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _sectionQuantities[secId] = int.tryParse(val) ?? 0;
                                      });
                                    },
                                    controller: TextEditingController(
                                      text: _sectionQuantities[secId] == 0 ? '0' : _sectionQuantities[secId].toString(),
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Qns',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'Outfit'),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B), size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _quantityMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _quantityMode = mode;
        });
        // Auto trigger selection when clicking
        final qty = int.tryParse(_quantityController.text.trim()) ?? 10;
        _selectByQuantity(qty, mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF20B486) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? const Color(0xFF20B486) : const Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionListPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header Tab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEFF2F5))),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open, color: Color(0xFF20B486), size: 20),
                const SizedBox(width: 8),
                Text(
                  _currentSectionTitle.isNotEmpty ? _currentSectionTitle : 'Question List',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Showing selected questions ($_totalElements total)',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'Outfit'),
                ),
                const Spacer(),
                // Search field
                SizedBox(
                  width: 250,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                      _loadSectionQuestions(0, search: val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for question...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontFamily: 'Outfit'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 16),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
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
                    style: const TextStyle(fontSize: 13, fontFamily: 'Outfit', color: Color(0xFF1E293B)),
                  ),
                ),
              ],
            ),
          ),

          // Questions list content
          _isLoadingQuestions
              ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
              : _questions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Text(
                          'No questions found in this section.',
                          style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit', fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      padding: const EdgeInsets.all(24),
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final int qId = q['id'] as int;
                        final isSelected = _selectedQuestionIds.contains(qId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedQuestionIds.remove(qId);
                                } else {
                                  _selectedQuestionIds.add(qId);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Checkbox
                                  Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF20B486) : Colors.white,
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF20B486) : const Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  // Question details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'QUESTION $qId',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Color(0xFF475569),
                                                fontFamily: 'Outfit',
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                (q['categoryName'] as String? ?? 'SINGLE CHOICE').toUpperCase(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  color: Color(0xFF475569),
                                                  fontFamily: 'Outfit',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          q['questionText'] as String,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0F172A),
                                            fontFamily: 'Outfit',
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

          // Pagination Controls
          if (!_isLoadingQuestions && _totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEFF2F5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF64748B)),
                    onPressed: _currentPage > 0
                        ? () => _loadSectionQuestions(_currentPage - 1, search: _searchQuery)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF20B486),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_currentPage + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
                    onPressed: _currentPage < _totalPages - 1
                        ? () => _loadSectionQuestions(_currentPage + 1, search: _searchQuery)
                        : null,
                  ),
                ],
              ),
            ),
          
          // Dash Plus Add Question Button (mock function)
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
            child: OutlinedButton.icon(
              onPressed: () {
                if (_currentSectionId == null) {
                  ToastHelper.showError(context, 'Please select a section first.');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddNewQuestionPage(
                      courseId: widget.courseId,
                      courseTitle: widget.courseTitle,
                      trainerName: widget.trainerName,
                      trainerInitials: widget.trainerInitials,
                      sections: widget.sections,
                      sectionIndex: widget.sectionIndex,
                      sectionId: _currentSectionId!,
                      sectionTitle: _currentSectionTitle,
                      onQuestionCreated: (newQuestionId) {
                        setState(() {
                          _selectedQuestionIds.add(newQuestionId);
                        });
                        _loadSectionQuestions(_currentPage, search: _searchQuery);
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add Question',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF20B486),
                side: BorderSide(color: const Color(0xFF20B486).withAlpha(102), style: BorderStyle.solid),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPersistentBar() {
    final hasSelected = _selectedQuestionIds.isNotEmpty;
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFF2F5))),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: Offset(0, -4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            hasSelected
                ? '${_selectedQuestionIds.length} Questions Selected'
                : 'No Questions Selected',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: hasSelected ? _saveSelectedQuestions : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Add Questions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              disabledForegroundColor: const Color(0xFF94A3B8),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
