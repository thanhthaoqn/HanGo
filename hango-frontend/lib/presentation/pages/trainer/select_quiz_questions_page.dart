import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../widgets/trainer_action_required_card.dart';
import '../../../utils/config.dart';
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
  final String? courseStatus;
  final String? rejectionReason;

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
    this.courseStatus,
    this.rejectionReason,
  });

  @override
  State<SelectQuizQuestionsPage> createState() => _SelectQuizQuestionsPageState();
}

class _SelectQuizQuestionsPageState extends State<SelectQuizQuestionsPage> {
  final _authService = AuthService();
  
  // State
  List<dynamic> _quizQuestions = [];
  bool _isLoadingQuestions = true;
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  final int _pageSize = 10;

  List<dynamic> _skillsList = [];
  List<dynamic> _groupTypesList = [];
  List<dynamic> _difficultyList = [];

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadQuizQuestions(0);
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final token = await _authService.getToken();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/metadata/parameters?type=SKILL'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() {
          _skillsList = jsonDecode(utf8.decode(res.bodyBytes));
        });
      }
      
      final resGroup = await http.get(
        Uri.parse('$apiBaseUrl/metadata/parameters?type=GROUP_TYPE'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resGroup.statusCode == 200) {
        setState(() {
          _groupTypesList = jsonDecode(utf8.decode(resGroup.bodyBytes));
        });
      }

      final resDiff = await http.get(
        Uri.parse('$apiBaseUrl/metadata/parameters?type=DIFFICULTY'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resDiff.statusCode == 200) {
        setState(() {
          _difficultyList = jsonDecode(utf8.decode(resDiff.bodyBytes));
        });
      }
    } catch (e) {
      debugPrint('Failed to load metadata: $e');
    }
  }

  // Load Paginated Questions associated with this Quiz Lesson
  Future<void> _loadQuizQuestions(int page) async {
    setState(() {
      _isLoadingQuestions = true;
      _currentPage = page;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final uri = Uri.parse('$apiBaseUrl/trainer/lessons/${widget.lessonId}/questions?page=$page&size=$_pageSize');
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
          _quizQuestions = data['content'] as List<dynamic>;
          _totalElements = data['totalElements'] as int;
          _totalPages = data['totalPages'] as int;
          _isLoadingQuestions = false;
        });
      } else {
        ToastHelper.showError(context, 'Failed to load quiz questions: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoadingQuestions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading quiz questions: $e');
      ToastHelper.showError(context, 'Connection error: $e');
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  // Associate new questions to this quiz
  Future<void> _associateQuestionsToQuiz(List<int> questionIds) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      // 1. Fetch all existing question IDs associated with the quiz
      final getUri = Uri.parse('$apiBaseUrl/trainer/lessons/${widget.lessonId}/questions?page=0&size=999');
      final getRes = await http.get(
        getUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      List<int> currentIds = [];
      if (getRes.statusCode == 200) {
        final data = jsonDecode(utf8.decode(getRes.bodyBytes));
        final list = data['content'] as List<dynamic>;
        currentIds = list.map((q) => q['id'] as int).toList();
      }

      for (var id in questionIds) {
        if (!currentIds.contains(id)) {
          currentIds.add(id);
        }
      }

      // 2. Save the updated list back to the lesson
      final postUri = Uri.parse('$apiBaseUrl/trainer/lessons/${widget.lessonId}/questions');
      final postRes = await http.post(
        postUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'questionIds': currentIds,
        }),
      );

      if (postRes.statusCode == 200) {
        _loadQuizQuestions(0);
      } else {
        ToastHelper.showError(context, 'Failed to associate new questions to quiz.');
      }
    } catch (e) {
      debugPrint('Error associating questions: $e');
    }
  }

  // Delete question association from this quiz
  Future<void> _deleteQuestionFromQuiz(int questionId) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      // 1. Fetch all existing question IDs
      final getUri = Uri.parse('$apiBaseUrl/trainer/lessons/${widget.lessonId}/questions?page=0&size=999');
      final getRes = await http.get(
        getUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      List<int> currentIds = [];
      if (getRes.statusCode == 200) {
        final data = jsonDecode(utf8.decode(getRes.bodyBytes));
        final list = data['content'] as List<dynamic>;
        currentIds = list.map((q) => q['id'] as int).toList();
      }

      currentIds.remove(questionId);

      // 2. Save the updated list back to the quiz
      final postUri = Uri.parse('$apiBaseUrl/trainer/lessons/${widget.lessonId}/questions');
      final postRes = await http.post(
        postUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'questionIds': currentIds,
        }),
      );

      if (postRes.statusCode == 200) {
        ToastHelper.showSuccess(context, 'Question removed from quiz.');
        _loadQuizQuestions(0);
      } else {
        ToastHelper.showError(context, 'Failed to remove question.');
      }
    } catch (e) {
      debugPrint('Error removing question: $e');
    }
  }

  // Show dialog to add questions from Question Bank
  Future<void> _showAddFromQuestionBankDialog() async {
    bool isLoading = false;
    bool initialLoaded = false;
    List<dynamic> bankQuestions = [];
    Set<int> selectedIds = {};
    String searchQuery = '';
    
    // Filter states
    int? selectedSkillId;
    int? selectedCategoryId;
    int? selectedDifficultyId;
    String sortBy = 'NEWEST';

    List<dynamic> skillsList = [];
    List<dynamic> categoriesList = [];
    List<dynamic> difficultyList = [];

    Future<void> fetchFilters(StateSetter setStateSB) async {
      try {
        final token = await _authService.getToken();
        if (token == null) return;

        // Fetch Skills
        http.get(Uri.parse('$apiBaseUrl/metadata/parameters?type=SKILL_TYPE'), headers: {'Authorization': 'Bearer $token'})
          .then((res) {
            if (res.statusCode == 200) setStateSB(() => skillsList = jsonDecode(utf8.decode(res.bodyBytes)));
        });

        // Fetch Categories
        http.get(Uri.parse('$apiBaseUrl/metadata/categories'), headers: {'Authorization': 'Bearer $token'})
          .then((res) {
            if (res.statusCode == 200) setStateSB(() => categoriesList = jsonDecode(utf8.decode(res.bodyBytes)));
        });

        // Fetch Difficulties
        http.get(Uri.parse('$apiBaseUrl/metadata/parameters?type=DIFFICULTY'), headers: {'Authorization': 'Bearer $token'})
          .then((res) {
            if (res.statusCode == 200) setStateSB(() => difficultyList = jsonDecode(utf8.decode(res.bodyBytes)));
        });
      } catch (e) {
        debugPrint('Error fetching filters: $e');
      }
    }

    Future<void> fetchBank(StateSetter setStateSB) async {
      setStateSB(() => isLoading = true);
      try {
        final token = await _authService.getToken();
        if (token == null) return;
        
        String url = '$apiBaseUrl/trainer/question-bank?type=QUIZ&search=$searchQuery&sortBy=$sortBy';
        if (selectedSkillId != null) url += '&skillId=$selectedSkillId';
        if (selectedCategoryId != null) url += '&categoryId=$selectedCategoryId';
        if (selectedDifficultyId != null) url += '&difficultyId=$selectedDifficultyId';
        
        final uri = Uri.parse(url);
        final response = await http.get(uri, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        });
        
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          setStateSB(() {
            bankQuestions = data as List<dynamic>;
            isLoading = false;
            initialLoaded = true;
          });
        } else {
          setStateSB(() {
            isLoading = false;
            initialLoaded = true;
          });
        }
      } catch (e) {
        setStateSB(() {
          isLoading = false;
          initialLoaded = true;
        });
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            if (!initialLoaded && !isLoading) {
              fetchBank(setStateSB);
              fetchFilters(setStateSB);
            }
            
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add from Question Bank', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 500,
                child: Column(
                  children: [
                    // Row 1: Search & Sort
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            onSubmitted: (val) {
                              searchQuery = val;
                              fetchBank(setStateSB);
                            },
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search questions...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF20B486))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: sortBy,
                                items: const [
                                  DropdownMenuItem(value: 'NEWEST', child: Text('Newest', style: TextStyle(fontFamily: 'Outfit', fontSize: 13))),
                                  DropdownMenuItem(value: 'OLDEST', child: Text('Oldest', style: TextStyle(fontFamily: 'Outfit', fontSize: 13))),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setStateSB(() => sortBy = val);
                                    fetchBank(setStateSB);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2: Category, Skill, Difficulty
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                hint: const Text('All Categories', style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                value: selectedCategoryId,
                                items: [
                                  const DropdownMenuItem<int>(value: null, child: Text('All Categories', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B)))),
                                  ...categoriesList.map((cat) => DropdownMenuItem<int>(
                                        value: cat['id'] as int,
                                        child: Text(cat['name'] ?? '', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                      )).toList(),
                                ],
                                onChanged: (val) {
                                  setStateSB(() => selectedCategoryId = val);
                                  fetchBank(setStateSB);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                hint: const Text('All Skills', style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                value: selectedSkillId,
                                items: [
                                  const DropdownMenuItem<int>(value: null, child: Text('All Skills', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B)))),
                                  ...skillsList.map((skill) => DropdownMenuItem<int>(
                                        value: skill['id'] as int,
                                        child: Text(skill['paramValue'] ?? '', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                      )).toList(),
                                ],
                                onChanged: (val) {
                                  setStateSB(() => selectedSkillId = val);
                                  fetchBank(setStateSB);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                hint: const Text('All Difficulties', style: TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                value: selectedDifficultyId,
                                items: [
                                  const DropdownMenuItem<int>(value: null, child: Text('All Difficulties', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Color(0xFF64748B)))),
                                  ...difficultyList.map((diff) => DropdownMenuItem<int>(
                                        value: diff['id'] as int,
                                        child: Text(diff['paramValue'] ?? '', style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                      )).toList(),
                                ],
                                onChanged: (val) {
                                  setStateSB(() => selectedDifficultyId = val);
                                  fetchBank(setStateSB);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)))
                          : bankQuestions.isEmpty
                              ? const Center(child: Text('No questions found.', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')))
                              : ListView.builder(
                                  itemCount: bankQuestions.length,
                                  itemBuilder: (context, index) {
                                    final q = bankQuestions[index];
                                    final int qId = q['id'] as int;
                                    final bool isSelected = selectedIds.contains(qId);
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isSelected ? const Color(0xFF20B486) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                        color: isSelected ? const Color(0xFFE2F9F3) : Colors.white,
                                      ),
                                      child: CheckboxListTile(
                                        activeColor: const Color(0xFF20B486),
                                        value: isSelected,
                                        onChanged: (val) {
                                          setStateSB(() {
                                            if (val == true) {
                                              selectedIds.add(qId);
                                            } else {
                                              selectedIds.remove(qId);
                                            }
                                          });
                                        },
                                        title: Text(q['questionText'] ?? '', style: const TextStyle(fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                                        subtitle: Text(q['categoryName'] ?? 'Multiple Choice', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                                        controlAffinity: ListTileControlAffinity.leading,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
                ),
                ElevatedButton(
                  onPressed: selectedIds.isEmpty ? null : () {
                    Navigator.pop(ctx);
                    _associateQuestionsToQuiz(selectedIds.toList());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Add Selected (${selectedIds.length})', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // Edit Question Dialog
  Future<void> _showEditQuestionDialog(Map<String, dynamic> q) async {
    final TextEditingController textCtrl = TextEditingController(text: q['questionText'] ?? '');
    final TextEditingController explCtrl = TextEditingController(text: q['explanation'] ?? '');
    final TextEditingController passageCtrl = TextEditingController(text: q['passageText'] ?? (q['questionGroup'] != null ? q['questionGroup']['contextText'] : ''));
    int? currentSkillParamId = q['skillParamId'] ?? (q['skillParam'] != null ? q['skillParam']['id'] : null);
    int? currentGroupTypeParamId = q['questionGroup'] != null ? (q['questionGroup']['groupTypeParamId'] ?? (q['questionGroup']['groupTypeParam'] != null ? q['questionGroup']['groupTypeParam']['id'] : null)) : null;
    int? currentDifficultyParamId = q['difficultyParamId'] ?? (q['difficultyParam'] != null ? q['difficultyParam']['id'] : null);
    bool isGrouped = q['passageText'] != null || q['questionGroup'] != null;
    
    List<String> options = [];
    if (q['options'] != null) {
      options = List<String>.from(q['options']);
    }
    List<TextEditingController> optCtrls = options.map((o) => TextEditingController(text: o)).toList();
    if (optCtrls.isEmpty) {
      optCtrls.add(TextEditingController());
      optCtrls.add(TextEditingController());
    }
    
    int correctIndex = q['correctIndex'] ?? 0;
    if (correctIndex >= optCtrls.length) correctIndex = 0;
    
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Question', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isGrouped) ...[
                        const Text('Passage Text (Group Context)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passageCtrl,
                          maxLines: 4,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF20B486))),
                            hintText: 'Enter passage text...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Group Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButton<int>(
                            isExpanded: true, underline: const SizedBox(),
                            value: currentGroupTypeParamId,
                            hint: const Text('Select Group Type'),
                            items: [
                              const DropdownMenuItem<int>(value: null, child: Text('None')),
                              ..._groupTypesList.map((g) => DropdownMenuItem<int>(value: g['id'], child: Text(g['paramValue'] ?? ''))),
                            ],
                            onChanged: (val) => setStateSB(() => currentGroupTypeParamId = val),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text('Skill Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButton<int>(
                          isExpanded: true, underline: const SizedBox(),
                          value: currentSkillParamId,
                          hint: const Text('Select Skill Type'),
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('None')),
                            ..._skillsList.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['paramValue'] ?? ''))),
                          ],
                          onChanged: (val) => setStateSB(() => currentSkillParamId = val),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButton<int>(
                          isExpanded: true, underline: const SizedBox(),
                          value: currentDifficultyParamId,
                          hint: const Text('Select Difficulty'),
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('None')),
                            ..._difficultyList.map((d) => DropdownMenuItem<int>(value: d['id'], child: Text(d['paramValue'] ?? ''))),
                          ],
                          onChanged: (val) => setStateSB(() => currentDifficultyParamId = val),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Question Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF20B486))),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: explCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF20B486))),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                      const SizedBox(height: 8),
                      ...List.generate(optCtrls.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: index,
                                groupValue: correctIndex,
                                activeColor: const Color(0xFF20B486),
                                onChanged: (val) {
                                  setStateSB(() {
                                    correctIndex = val!;
                                  });
                                },
                              ),
                              Expanded(
                                child: TextField(
                                  controller: optCtrls[index],
                                  decoration: InputDecoration(
                                    hintText: 'Option ${index + 1}',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF20B486))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                onPressed: () {
                                  if (optCtrls.length > 2) {
                                    setStateSB(() {
                                      optCtrls[index].dispose();
                                      optCtrls.removeAt(index);
                                      if (correctIndex == index) correctIndex = 0;
                                      else if (correctIndex > index) correctIndex--;
                                    });
                                  } else {
                                    ToastHelper.showError(ctx, 'Minimum 2 options required.');
                                  }
                                },
                              )
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setStateSB(() {
                            optCtrls.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
                        label: const Text('Add Option', style: TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving ? null : () async {
                    final qId = q['id'];
                    final updatedText = textCtrl.text.trim();
                    final updatedExpl = explCtrl.text.trim();
                    final updatedOpts = optCtrls.map((c) => c.text.trim()).toList();
                    
                    if (updatedText.isEmpty) {
                      ToastHelper.showError(ctx, 'Question text cannot be empty.');
                      return;
                    }
                    if (updatedOpts.any((o) => o.isEmpty)) {
                      ToastHelper.showError(ctx, 'All options must be filled.');
                      return;
                    }

                    setStateSB(() => isSaving = true);

                    try {
                      final token = await _authService.getToken();
                      final Map<String, dynamic> payload = {
                        "questionText": updatedText,
                        "explanation": updatedExpl,
                        "options": List.generate(updatedOpts.length, (i) => {
                          "optionText": updatedOpts[i],
                          "isCorrect": i == correctIndex
                        })
                      };
                      
                      if (isGrouped) {
                        payload["passageText"] = passageCtrl.text.trim();
                        if (q['questionGroup'] != null) {
                          payload["groupId"] = q['questionGroup']['id'];
                        }
                        if (currentGroupTypeParamId != null) {
                          payload["groupTypeParamId"] = currentGroupTypeParamId;
                        }
                      }
                      if (currentSkillParamId != null) {
                        payload["skillParamId"] = currentSkillParamId;
                      }
                      if (currentDifficultyParamId != null) {
                        payload["difficultyId"] = currentDifficultyParamId;
                      }
                      
                      final response = await http.put(
                        Uri.parse('$apiBaseUrl/sections/questions/$qId'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: jsonEncode(payload),
                      );

                      if (response.statusCode == 200) {
                        ToastHelper.showSuccess(ctx, 'Question updated successfully');
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadQuizQuestions(_currentPage);
                        }
                      } else {
                        ToastHelper.showError(ctx, 'Failed to update question.');
                        setStateSB(() => isSaving = false);
                      }
                    } catch (e) {
                      ToastHelper.showError(ctx, 'Error updating question: $e');
                      setStateSB(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
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
          InternalAppHeader(isMobile: false),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDesktop) _buildLeftSidebar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 24),
                        _buildMainContentCard(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildFooterBar(),
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

  Widget _buildLeftSidebar() {
    final activeColor = const Color(0xFF20B486);
    return Container(
      width: 280,
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
              Navigator.pop(context);
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

  Widget _buildMainContentCard() {
    final String activeSectionTitle = widget.sections[widget.sectionIndex]['title'] as String;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Section ${widget.sectionIndex + 1}: $activeSectionTitle',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 24),
          // Dashed border card container for list
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFCBD5E1),
                style: BorderStyle.solid,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'QUESTION LIST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                          letterSpacing: 0.5,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Question ($_totalElements)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Questions List
                _isLoadingQuestions
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: Color(0xFF20B486)),
                        ),
                      )
                    : _quizQuestions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'No questions in this quiz yet. Click "+ Add Question" below to add.',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontFamily: 'Outfit'),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _quizQuestions.length,
                            itemBuilder: (context, index) {
                              final q = _quizQuestions[index];
                              final int displayNum = (_currentPage * _pageSize) + index + 1;
                              final String text = q['questionText'] ?? '';
                              final String catName = q['categoryName'] ?? 'Single Choice';
                              final optionsList = q['options'] as List<dynamic>? ?? [];
                              final int optionsCount = optionsList.length;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    // #Num circle badge
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE2F9F3),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '#$displayNum',
                                        style: const TextStyle(
                                          color: Color(0xFF20B486),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (q['passageText'] != null && q['passageText'].toString().trim().isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Text(
                                                q['passageText'],
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF475569),
                                                  fontStyle: FontStyle.italic,
                                                  fontFamily: 'Outfit',
                                                ),
                                              ),
                                            ),
                                          ],
                                          Text(
                                            text,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E293B),
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              // Type badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE2E8F0),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  catName == 'Multiple Choice' ? 'Multiple Choice' : 'Single Answer',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF475569),
                                                    fontFamily: 'Outfit',
                                                  ),
                                                ),
                                              ),
                                              if (q['skillName'] != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    q['skillName'],
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1E3A8A),
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (q['groupTypeName'] != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF3C7),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    q['groupTypeName'],
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF92400E),
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (q['difficultyName'] != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE0E7FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    q['difficultyName'],
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF3730A3),
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              // Options count badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD1FAE5),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$optionsCount options',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF065F46),
                                                    fontFamily: 'Outfit',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 18),
                                      onPressed: () => _showEditQuestionDialog(q),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                                      onPressed: () => _deleteQuestionFromQuiz(q['id'] as int),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                const SizedBox(height: 16),
                // Add Question Buttons
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
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
                              sectionId: widget.sections[widget.sectionIndex]['id'] as int,
                              sectionTitle: widget.sections[widget.sectionIndex]['title'] as String,
                              onQuestionCreated: (newQuestionIds) {
                                _associateQuestionsToQuiz(newQuestionIds);
                              },
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF20B486)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      ),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
                      label: const Text(
                        'Add Question',
                        style: TextStyle(
                          color: Color(0xFF20B486),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddFromQuestionBankDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2F9F3),
                        foregroundColor: const Color(0xFF20B486),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      ),
                      icon: const Icon(Icons.library_books, size: 16),
                      label: const Text(
                        'Add from Question Bank',
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
            ),
          ),
          // Pagination Row at the bottom of the card
          if (_totalPages > 1) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_left, size: 20),
                  onPressed: _currentPage > 0 ? () => _loadQuizQuestions(_currentPage - 1) : null,
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20B486),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
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
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_right, size: 20),
                  onPressed: _currentPage < _totalPages - 1 ? () => _loadQuizQuestions(_currentPage + 1) : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFF2F5))),
      ),
      child: Row(
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
            onPressed: () async {
              ToastHelper.showSuccess(context, 'Quiz questions saved successfully');
              await widget.onSectionsChanged(widget.sections);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
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
    );
  }
}
