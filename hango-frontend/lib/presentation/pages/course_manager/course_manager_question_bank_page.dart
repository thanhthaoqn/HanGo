import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../services/hango_api.dart';
import '../../../../utils/config.dart';
import '../../widgets/shared_header.dart';
import '../trainer/question_bank/widgets/question_search_bar.dart';
import '../trainer/question_bank/widgets/question_table.dart';
import 'question_bank/course_manager_create_question_page.dart';
import 'question_bank/models/course_manager_question.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../../../utils/toast_helper.dart';

class CourseManagerQuestionBankPage extends StatefulWidget {
  const CourseManagerQuestionBankPage({Key? key}) : super(key: key);

  @override
  State<CourseManagerQuestionBankPage> createState() => _CourseManagerQuestionBankPageState();
}

class _CourseManagerQuestionBankPageState extends State<CourseManagerQuestionBankPage> {
  final _authService = AuthService();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  String _errorMessage = '';

  // Filter States
  String _selectedType = 'PUBLIC';
  String _searchQuery = '';
  String _sortBy = 'NEWEST';
  int _currentPage = 1;
  static const int _pageSize = 5;

  List<CourseManagerQuestion> _allQuestions = [];
  List<CourseManagerQuestion> _displayedQuestions = [];
  Timer? _debounceTimer;

  String get apiBaseUrl => EnvConfig.apiBaseUrl;

  void initState() {
    super.initState();
    _fetchQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }



  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final api = HangoApi(baseUrl: apiBaseUrl, token: token);
      final questionsList = await api.getTrainerQuestions(
        type: _selectedType,
        search: _searchQuery,
        sortBy: _sortBy,
      );

      setState(() {
        _allQuestions = questionsList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching questions from database: $e');
      setState(() {
        _allQuestions = [];
        _isLoading = false;
        _errorMessage = 'Failed to load questions. Please try again.';
      });
    }
  }



  void _handleSearch(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _currentPage = 1;
      });
      _fetchQuestions();
    });
  }

  void _handleTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      _currentPage = 1;
    });
    _fetchQuestions();
  }

  void _handleSortChanged(String sort) {
    setState(() {
      _sortBy = sort;
      _currentPage = 1;
    });
    _fetchQuestions();
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        if (mounted) ToastHelper.showError(context, 'Failed to read file bytes');
        return;
      }

      var excel = Excel.decodeBytes(bytes);
      var sheetName = excel.tables.keys.firstWhere((k) => k != 'Rules', orElse: () => excel.tables.keys.first);
      var sheet = excel.tables[sheetName];

      if (sheet == null || sheet.maxRows < 3) {
        if (mounted) ToastHelper.showError(context, 'File is empty or invalid format');
        return;
      }

      var headerRow = sheet.rows[1];
      if (headerRow.length < 12 || 
          !headerRow[1]!.value.toString().contains('Order Index') ||
          !headerRow[2]!.value.toString().contains('Passage Text')) {
        if (mounted) ToastHelper.showError(context, 'File does not match the Hango template');
        return;
      }

      List<List<Data?>> firstQuestionRows = [];
      String? targetPassage;

      for (int i = 2; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty || row[0] == null) continue;

        String passage = row[2]?.value?.toString() ?? '';
        if (firstQuestionRows.isEmpty) {
          targetPassage = passage;
          firstQuestionRows.add(row);
        } else {
          if (passage == targetPassage) {
            firstQuestionRows.add(row);
          } else {
            break;
          }
        }
      }

      if (firstQuestionRows.isEmpty) {
        if (mounted) ToastHelper.showError(context, 'No questions found in the file');
        return;
      }

      bool isGroup = targetPassage != null && targetPassage.trim().isNotEmpty;
      String groupTypeName = isGroup ? (firstQuestionRows[0][12]?.value?.toString() ?? '') : '';

      List<Map<String, dynamic>> subQuestions = [];
      for (var row in firstQuestionRows) {
        String qText = row[3]?.value?.toString() ?? '';
        String optA = row[4]?.value?.toString() ?? '';
        String optB = row[5]?.value?.toString() ?? '';
        String optC = row[6]?.value?.toString() ?? '';
        String optD = row[7]?.value?.toString() ?? '';
        String correctAns = row[8]?.value?.toString().trim().toUpperCase() ?? 'A';
        String explanation = row[9]?.value?.toString() ?? '';
        String skillName = row[10]?.value?.toString() ?? '';
        String diffName = row[11]?.value?.toString() ?? '';

        if (qText.isEmpty) {
           if (mounted) ToastHelper.showError(context, 'Question Text is required in Excel');
           return;
        }

        subQuestions.add({
          'questionText': qText,
          'explanation': explanation,
          'skillName': skillName,
          'diffName': diffName,
          'options': [
            {'optionText': optA, 'isCorrect': correctAns == 'A'},
            {'optionText': optB, 'isCorrect': correctAns == 'B'},
            {'optionText': optC, 'isCorrect': correctAns == 'C'},
            {'optionText': optD, 'isCorrect': correctAns == 'D'},
          ]
        });
      }

      Map<String, dynamic> initialData = {
        'isGroup': isGroup,
        'groupTypeName': groupTypeName,
        'passageText': targetPassage ?? '',
        'subQuestions': subQuestions,
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseManagerCreateQuestionPage(
              initialData: initialData,
              isCourseManager: true,
            ),
          ),
        ).then((_) => _fetchQuestions());
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Failed to import Excel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    // Client-side pagination logic
    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, _allQuestions.length);
    _displayedQuestions = _allQuestions.isEmpty
        ? []
        : _allQuestions.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'question_bank')) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'question_bank')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QuestionSearchBar(
                                searchController: _searchController,
                                onSearchChanged: _handleSearch,
                                selectedType: _selectedType,
                                onTypeChanged: _handleTypeChanged,
                                sortBy: _sortBy,
                                onSortChanged: _handleSortChanged,
                                onCreatePressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const CourseManagerCreateQuestionPage(isCourseManager: true)),
                                  ).then((_) => _fetchQuestions());
                                },
                                onImportPressed: _importFromExcel,
                                onRefreshPressed: _fetchQuestions,
                              ),
                              const SizedBox(height: 24),
                              QuestionTable(
                                questions: _displayedQuestions,
                                isLoading: _isLoading,
                                currentPage: _currentPage,
                                totalRecords: _allQuestions.length,
                                pageSize: _pageSize,
                                onPageChanged: (page) {
                                  setState(() {
                                    _currentPage = page;
                                  });
                                },
                                onViewPressed: (q) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CourseManagerCreateQuestionPage(
                                      question: q,
                                      isReadOnly: true,
                                      isCourseManager: true,
                                    )),
                                  );
                                },
                                onEditPressed: (q) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CourseManagerCreateQuestionPage(
                                      question: q,
                                      isEdit: true,
                                      isCourseManager: true,
                                    )),
                                  ).then((_) => _fetchQuestions());
                                },
                                onStatusToggled: (q, isPublic) async {
                                  final oldStatus = q.status;
                                  final newStatus = isPublic ? 'PUBLIC' : 'PRIVATE';
                                  
                                  // Optimistic UI Update
                                  setState(() {
                                    q.status = newStatus;
                                  });

                                  try {
                                    final token = await _authService.getToken();
                                    if (token != null) {
                                      final api = HangoApi(baseUrl: apiBaseUrl, token: token);
                                      await api.toggleQuestionStatus(q.id, newStatus, isGroup: q.isGroup);
                                    } else {
                                      throw Exception('No token');
                                    }
                                  } catch (e) {
                                    // Revert on failure
                                    setState(() {
                                      q.status = oldStatus;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to update status: $e')),
                                      );
                                    }
                                  }
                                },
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
        ],
      ),
    );
  }



  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Question Bank',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }
}
