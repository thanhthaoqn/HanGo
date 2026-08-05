import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../services/hango_api.dart';
import '../../../../utils/config.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'question_bank/widgets/question_search_bar.dart';
import 'question_bank/widgets/question_table.dart';
import 'question_bank/course_manager_create_question_page.dart';
import 'question_bank/models/course_manager_question.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/download_helper.dart';

class CourseManagerQuestionBankPage extends StatefulWidget {
  const CourseManagerQuestionBankPage({Key? key}) : super(key: key);

  @override
  State<CourseManagerQuestionBankPage> createState() =>
      _CourseManagerQuestionBankPageState();
}

class _CourseManagerQuestionBankPageState
    extends State<CourseManagerQuestionBankPage> {
  final _authService = AuthService();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';

  // Filter States
  String _selectedType = '';
  String _searchQuery = '';
  String _sortBy = 'NEWEST';
  int _currentPage = 1;
  static const int _pageSize = 5;

  List<CourseManagerQuestion> _allQuestions = [];
  List<CourseManagerQuestion> _displayedQuestions = [];
  Timer? _debounceTimer;

  // Metadata for filters
  List<Map<String, dynamic>>? _skills = [];
  List<Map<String, dynamic>>? _groupTypes = [];
  List<Map<String, dynamic>>? _difficulties = [];
  int? _selectedSkillId;
  int? _selectedGroupTypeId;
  int? _selectedDifficultyId;

  String get apiBaseUrl => EnvConfig.apiBaseUrl;

  void initState() {
    super.initState();
    _fetchFilters();
    _fetchQuestions();
  }

  Future<void> _fetchFilters() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      final api = HangoApi(baseUrl: apiBaseUrl, token: token);
      final skills = await api.getSystemParameters('SKILL_TYPE');
      final groupTypes = await api.getSystemParameters('GROUP_TYPE');
      final difficulties = await api.getSystemParameters('DIFFICULTY');
      if (mounted) {
        setState(() {
          _skills = skills;
          _groupTypes = groupTypes;
          _difficulties = difficulties;
        });
      }
    } catch (e) {
      debugPrint('Error fetching filters: $e');
    }
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
      final questionsList = await api.getCourseManagerQuestions(
        type: _selectedType,
        search: _searchQuery,
        sortBy: _sortBy,
        skillId: _selectedSkillId,
        categoryId: _selectedGroupTypeId,
        difficultyId: _selectedDifficultyId,
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
        if (mounted)
          ToastHelper.showError(context, 'Failed to read file bytes');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      var excel = Excel.decodeBytes(List<int>.from(bytes));
      var sheet = excel.tables['QUESTIONS'];
      if (sheet == null) {
        var sheetName = excel.tables.keys.firstWhere(
          (k) =>
              !k.toUpperCase().contains('RULES') &&
              !k.toUpperCase().contains('README'),
          orElse: () => excel.tables.keys.last,
        );
        sheet = excel.tables[sheetName];
      }

      if (sheet == null || sheet.maxRows < 3) {
        setState(() {
          _isLoading = false;
        });
        if (mounted)
          ToastHelper.showError(context, 'File is empty or invalid format');
        return;
      }

      var headerRow = sheet.rows[1];
      if (headerRow.length < 12 ||
          !headerRow[0]!.value.toString().contains('Order Index') ||
          !headerRow[1]!.value.toString().contains('Passage Text')) {
        setState(() {
          _isLoading = false;
        });
        if (mounted)
          ToastHelper.showError(
            context,
            'File does not match the Hango template',
          );
        return;
      }

      List<Map<String, dynamic>> groupsList = [];
      Map<String, Map<String, dynamic>> groupMap = {};

      for (int i = 2; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty ||
            row.length < 3 ||
            row[2] == null ||
            row[2]?.value?.toString().trim().isEmpty == true)
          continue;

        String passage = row[1]?.value?.toString().trim() ?? '';
        String qText = row[2]?.value?.toString() ?? '';
        String optA = row[3]?.value?.toString() ?? '';
        String optB = row[4]?.value?.toString() ?? '';
        String optC = row[5]?.value?.toString() ?? '';
        String optD = row[6]?.value?.toString() ?? '';
        String correctAns =
            row[7]?.value?.toString().trim().toUpperCase() ?? 'A';
        String explanation = row[8]?.value?.toString() ?? '';
        String skillName = row[9]?.value?.toString() ?? '';
        String diffName = row[10]?.value?.toString() ?? '';
        String groupTypeName = row[11]?.value?.toString() ?? '';

        Map<String, dynamic> subQ = {
          'questionText': qText,
          'explanation': explanation,
          'skillName': skillName,
          'diffName': diffName,
          'options': [
            {'optionText': optA, 'isCorrect': correctAns == 'A'},
            {'optionText': optB, 'isCorrect': correctAns == 'B'},
            {'optionText': optC, 'isCorrect': correctAns == 'C'},
            {'optionText': optD, 'isCorrect': correctAns == 'D'},
          ],
        };

        if (passage.isEmpty) {
          groupsList.add({
            'isGroup': false,
            'passageText': '',
            'groupTypeName': '',
            'subQuestions': [subQ],
          });
        } else {
          if (!groupMap.containsKey(passage)) {
            groupMap[passage] = {
              'isGroup': true,
              'passageText': passage,
              'groupTypeName': groupTypeName,
              'subQuestions': <Map<String, dynamic>>[],
            };
            groupsList.add(groupMap[passage]!);
          }
          (groupMap[passage]!['subQuestions'] as List).add(subQ);
        }
      }

      if (groupsList.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) ToastHelper.showError(context, 'No valid questions found');
        return;
      }

      Map<String, dynamic> initialData = {'groups': groupsList};

      setState(() {
        _isLoading = false;
      });

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
      setState(() {
        _isLoading = false;
      });
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
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: '',),
      drawer: !isDesktop
          ? const Drawer(
              child: CourseManagerSidebar(currentRoute: 'question_bank'),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 240,
              child: CourseManagerSidebar(currentRoute: 'question_bank'),
            ),
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
                                onCreatePressed: () {}, // Moved to header
                                onImportPressed: () {}, // Moved to header
                                onRefreshPressed: _fetchQuestions,
                                isCourseManager: true,
                                skills: _skills,
                                groupTypes: _groupTypes,
                                difficulties: _difficulties,
                                selectedSkillId: _selectedSkillId,
                                onSkillChanged: (val) {
                                  setState(() {
                                    _selectedSkillId = val;
                                    _currentPage = 1;
                                  });
                                  _fetchQuestions();
                                },
                                selectedGroupTypeId: _selectedGroupTypeId,
                                onGroupTypeChanged: (val) {
                                  setState(() {
                                    _selectedGroupTypeId = val;
                                    _currentPage = 1;
                                  });
                                  _fetchQuestions();
                                },
                                selectedDifficultyId: _selectedDifficultyId,
                                onDifficultyChanged: (val) {
                                  setState(() {
                                    _selectedDifficultyId = val;
                                    _currentPage = 1;
                                  });
                                  _fetchQuestions();
                                },
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
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CourseManagerCreateQuestionPage(
                                            question: q,
                                            isReadOnly: true,
                                            isCourseManager: true,
                                          ),
                                    ),
                                  );
                                },
                                onEditPressed: (q) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CourseManagerCreateQuestionPage(
                                            question: q,
                                            isEdit: true,
                                            isCourseManager: true,
                                          ),
                                    ),
                                  ).then((_) => _fetchQuestions());
                                },
                                onStatusToggled: (q, isPublic) async {
                                  final oldStatus = q.status;
                                  final newStatus = isPublic
                                      ? 'PUBLIC'
                                      : 'PRIVATE';

                                  // Optimistic UI Update
                                  setState(() {
                                    q.status = newStatus;
                                  });

                                  try {
                                    final token = await _authService.getToken();
                                    if (token != null) {
                                      final api = HangoApi(
                                        baseUrl: apiBaseUrl,
                                        token: token,
                                      );
                                      await api.toggleQuestionStatus(
                                        q.id,
                                        newStatus,
                                        isGroup: q.isGroup,
                                      );
                                    } else {
                                      throw Exception('No token');
                                    }
                                  } catch (e) {
                                    // Revert on failure
                                    setState(() {
                                      q.status = oldStatus;
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to update status: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                isCourseManager: true,
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
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final token = await _authService.getToken();
                if (token == null)
                  throw Exception('Authentication token not found');
                final api = HangoApi(baseUrl: apiBaseUrl, token: token);
                final bytes = await api.downloadQuestionBankTemplate();
                downloadBytes(
                  bytes: bytes,
                  filename: 'Hango_Question_Bank_Import_Template.xlsx',
                  mimeType:
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
              } catch (e) {
                if (context.mounted)
                  ToastHelper.showError(
                    context,
                    'Could not download template: $e',
                  );
              }
            },
            icon: const Icon(
              Icons.download_outlined,
              color: Color(0xFF20B486),
              size: 18,
            ),
            label: const Text(
              'Download Template',
              style: TextStyle(
                color: Color(0xFF20B486),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: Color(0xFF20B486)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _importFromExcel,
            icon: const Icon(
              Icons.file_upload_outlined,
              color: Color(0xFF1E293B),
              size: 18,
            ),
            label: const Text(
              'Import Excel',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseManagerCreateQuestionPage(
                    isCourseManager: true,
                  ),
                ),
              ).then((_) => _fetchQuestions());
            },
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Create Question',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
