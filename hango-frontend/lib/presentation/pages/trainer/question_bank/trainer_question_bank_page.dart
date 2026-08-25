import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../services/hango_api.dart';
import '../../../../utils/config.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/download_helper.dart';
import '../../../../domain/model/exam_import_error.dart';
import '../../course_manager/exam_import_error_dialog.dart';
import '../../course_manager/question_bank/course_manager_create_question_page.dart';
import '../../course_manager/question_bank/models/course_manager_question.dart';
import '../../course_manager/question_bank/widgets/question_search_bar.dart';
import '../../course_manager/question_bank/widgets/question_table.dart';
import '../../../widgets/trainer/trainer_sidebar.dart';
import '../trainer_profile_page.dart';
import '../trainer_dashboard_page.dart';

class TrainerQuestionBankPage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerQuestionBankPage({super.key, this.isEmbedded = false});

  @override
  State<TrainerQuestionBankPage> createState() =>
      _TrainerQuestionBankPageState();
}

class _TrainerQuestionBankPageState extends State<TrainerQuestionBankPage> {
  final _authService = AuthService();
  final _searchController = TextEditingController();

  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _isLoading = true;
  String _errorMessage = '';

  // Filter States
  String _selectedType = 'ALL';
  String _searchQuery = '';
  String _sortBy = 'NEWEST';
  int? _usageType; // null = All, 1 = Quiz, 2 = Exam
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
  bool? _selectedIsGroup;

  CourseManagerQuestion? _viewingQuestion;
  CourseManagerQuestion? _editingQuestion;
  bool _isCreatingQuestion = false;

  String get apiBaseUrl => EnvConfig.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchFilters();
    _fetchQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
      _trainerAvatarUrl = avatarUrl;
    });
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
        groupTypeId: _selectedGroupTypeId,
        difficultyId: _selectedDifficultyId,
        usageType: _usageType,
        isGroup: _selectedIsGroup,
      );

      if (!mounted) return;
      setState(() {
        _allQuestions = questionsList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching questions from database: $e');
      if (!mounted) return;
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

      // Allow UI to render the loading indicator before heavy parsing blocks the thread
      await Future.delayed(const Duration(milliseconds: 100));

      var decoder = SpreadsheetDecoder.decodeBytes(List<int>.from(bytes));
      var sheet = decoder.tables['QUESTIONS'];
      if (sheet == null) {
        var sheetName = decoder.tables.keys.firstWhere(
          (k) =>
              !k.toUpperCase().contains('RULES') &&
              !k.toUpperCase().contains('README'),
          orElse: () => decoder.tables.keys.last,
        );
        sheet = decoder.tables[sheetName];
      }

      final allRows = sheet?.rows ?? [];
      if (sheet == null || allRows.length < 3) {
        setState(() {
          _isLoading = false;
        });
        if (mounted)
          ToastHelper.showError(context, 'File is empty or invalid format');
        return;
      }

      var headerRow = allRows[1];
      String headerCell0 = headerRow.isNotEmpty
          ? (headerRow[0]?.toString() ?? '')
          : '';
      String headerCell1 = headerRow.length > 1
          ? (headerRow[1]?.toString() ?? '')
          : '';
      if (headerRow.length < 12 ||
          !headerCell0.contains('Order Index') ||
          !headerCell1.contains('Passage Text')) {
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

      // Ensure filters are loaded before validating
      if ((_skills == null || _skills!.isEmpty) ||
          (_difficulties == null || _difficulties!.isEmpty) ||
          (_groupTypes == null || _groupTypes!.isEmpty)) {
        await _fetchFilters();
      }

      final skillOptions = _skills ?? [];
      final difficultyOptions = _difficulties ?? [];
      final groupTypeOptions = _groupTypes ?? [];

      bool paramExists(List<Map<String, dynamic>> options, String name) =>
          options.isEmpty || // skip validation if options not yet loaded
          options.any(
            (o) =>
                (o['paramValue']?.toString().toLowerCase() ?? '') ==
                name.toLowerCase(),
          );

      List<Map<String, dynamic>> groupsList = [];
      Map<String, Map<String, dynamic>> groupMap = {};
      List<ExamImportError> errors = [];

      for (int i = 2; i < allRows.length; i++) {
        var row = allRows[i];
        int rowNum = i + 1;

        String cell(int idx) =>
            (idx < row.length ? row[idx]?.toString() : null)?.trim() ?? '';

        String passage = cell(1);
        String qText = cell(2);
        String optA = cell(3);
        String optB = cell(4);
        String optC = cell(5);
        String optD = cell(6);
        String correctAns = cell(7).toUpperCase();
        String explanation = cell(8);
        String skillName = cell(9);
        String diffName = cell(10);
        String groupTypeName = cell(11);

        bool rowHasData =
            passage.isNotEmpty ||
            qText.isNotEmpty ||
            optA.isNotEmpty ||
            optB.isNotEmpty ||
            optC.isNotEmpty ||
            optD.isNotEmpty ||
            correctAns.isNotEmpty ||
            skillName.isNotEmpty ||
            diffName.isNotEmpty;
        if (!rowHasData) continue;

        if (qText.isEmpty) {
          errors.add(
            ExamImportError(
              sheet: 'QUESTIONS',
              row: rowNum,
              field: 'Question Text',
              errorType: 'MISSING_FIELD',
              message: 'Question Text is required at row $rowNum',
            ),
          );
        }

        if (!RegExp(r'^[A-D]$').hasMatch(correctAns)) {
          errors.add(
            ExamImportError(
              sheet: 'QUESTIONS',
              row: rowNum,
              field: 'Correct',
              errorType: 'INVALID_FORMAT',
              value: correctAns,
              message: 'Correct Answer must be A, B, C, or D at row $rowNum',
            ),
          );
        }

        if (skillName.isEmpty || !paramExists(skillOptions, skillName)) {
          errors.add(
            ExamImportError(
              sheet: 'QUESTIONS',
              row: rowNum,
              field: 'Skill',
              errorType: skillName.isEmpty ? 'MISSING_FIELD' : 'INVALID_VALUE',
              value: skillName,
              message: "Invalid or missing Skill '$skillName' at row $rowNum",
            ),
          );
        }

        if (diffName.isEmpty || !paramExists(difficultyOptions, diffName)) {
          errors.add(
            ExamImportError(
              sheet: 'QUESTIONS',
              row: rowNum,
              field: 'Difficulty',
              errorType: diffName.isEmpty ? 'MISSING_FIELD' : 'INVALID_VALUE',
              value: diffName,
              message:
                  "Invalid or missing Difficulty '$diffName' at row $rowNum",
            ),
          );
        }

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
            if (groupTypeName.isEmpty ||
                !paramExists(groupTypeOptions, groupTypeName)) {
              errors.add(
                ExamImportError(
                  sheet: 'QUESTIONS',
                  row: rowNum,
                  field: 'Group Type',
                  errorType: groupTypeName.isEmpty
                      ? 'MISSING_FIELD'
                      : 'INVALID_VALUE',
                  value: groupTypeName,
                  message:
                      "Invalid or missing Group Type '$groupTypeName' for passage at row $rowNum",
                ),
              );
            }
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

      setState(() {
        _isLoading = false;
      });

      if (groupsList.isEmpty && errors.isEmpty) {
        if (mounted) ToastHelper.showError(context, 'No valid questions found');
        return;
      }

      if (errors.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => ExamImportErrorDialog(errors: errors),
          );
        }
        return;
      }

      Map<String, dynamic> initialData = {'groups': groupsList};

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseManagerCreateQuestionPage(
              initialData: initialData,
              initialUsageType: _usageType ?? 3,
            ),
          ),
        ).then((_) => _fetchQuestions());
      }
    } catch (e, st) {
      debugPrint('=== IMPORT EXCEL ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Error importing excel: $e');
      debugPrint(st.toString());
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'System error, please try again later.');
      }
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

    final Widget content = _isCreatingQuestion
        ? CourseManagerCreateQuestionPage(
            isCourseManager: false,
            isEmbedded: true,
            initialUsageType: _usageType ?? 3,
            onBack: () {
              setState(() {
                _isCreatingQuestion = false;
              });
              _fetchQuestions();
            },
          )
        : _editingQuestion != null
        ? CourseManagerCreateQuestionPage(
            question: _editingQuestion,
            isEdit: true,
            isCourseManager: false,
            isEmbedded: true,
            onBack: () {
              setState(() {
                _editingQuestion = null;
              });
              _fetchQuestions();
            },
          )
        : _viewingQuestion != null
        ? CourseManagerCreateQuestionPage(
            question: _viewingQuestion,
            isReadOnly: true,
            isCourseManager: false,
            isEmbedded: true,
            onBack: () {
              setState(() {
                _viewingQuestion = null;
              });
            },
          )
        : _buildBodyContent(isDesktop);

    if (widget.isEmbedded) {
      return DefaultTabController(length: 2, child: content);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        drawer: !isDesktop
            ? const Drawer(child: TrainerSidebar(activeIndex: 3))
            : null,
        body: Row(
          children: [
            if (isDesktop)
              const SizedBox(width: 250, child: TrainerSidebar(activeIndex: 3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InternalAppHeader(isMobile: !isDesktop, showLogo: !isDesktop),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildUsageTypePill('All', null),
                const SizedBox(width: 8),
                _buildUsageTypePill('Quiz Question', 1),
                const SizedBox(width: 8),
                _buildUsageTypePill('Exam Question', 2),
              ],
            ),
          ),
          const SizedBox(height: 24),
          QuestionSearchBar(
            searchController: _searchController,
            onSearchChanged: _handleSearch,
            selectedType: _selectedType,
            onTypeChanged: _handleTypeChanged,
            sortBy: _sortBy,
            onSortChanged: _handleSortChanged,
            onCreatePressed: () {}, // Moved to welcome section
            onImportPressed: () {}, // Moved to welcome section
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
            selectedIsGroup: _selectedIsGroup,
            onIsGroupChanged: (val) {
              setState(() {
                _selectedIsGroup = val;
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
              setState(() {
                _viewingQuestion = q;
              });
            },
            onEditPressed: (q) {
              setState(() {
                _editingQuestion = q;
              });
            },
            onStatusToggled: (q, isPublic) async {
              final oldStatus = q.status;
              final newStatus = isPublic ? 'PUBLIC' : 'PRIVATE';
              setState(() {
                q.status = newStatus;
              });
              try {
                final token = await _authService.getToken();
                if (token != null) {
                  final api = HangoApi(baseUrl: apiBaseUrl, token: token);
                  await api.toggleQuestionStatus(
                    q.id,
                    newStatus,
                    isGroup: q.isGroup,
                  );
                } else {
                  throw Exception('No token');
                }
              } catch (e) {
                setState(() {
                  q.status = oldStatus;
                });
                if (context.mounted) {
                  ToastHelper.showError(
                    context,
                    'System error, please try again later.',
                  );
                }
              }
            },
            isCourseManager: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final title = const Text(
      'Question Bank',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
        fontFamily: 'Outfit',
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final actionButtons = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
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
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isCreatingQuestion = true;
            });
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
    );

    final isCompact = MediaQuery.of(context).size.width < 820;

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 16), actionButtons],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        actionButtons,
      ],
    );
  }

  Widget _unusedLegacyHeader(bool showMenuButton) {
    return Container(
      color: Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          // Breadcrumb
          Row(
            children: const [
              Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
              SizedBox(width: 4),
              Text(
                'Question Bank',
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
          // Actions
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 24,
                ),
                onPressed: () {
                  ToastHelper.show(context, 'No new notifications');
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // User profile widget with Popup Menu
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'dashboard') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerDashboardPage(),
                  ),
                );
              } else if (val == 'profile') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrainerProfilePage(),
                  ),
                );
              } else if (val == 'logout') {
                _authService.logout();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: const [
                    Icon(
                      Icons.dashboard_outlined,
                      size: 18,
                      color: Color(0xFF20B486),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: const [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'My Profile',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _trainerName,
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
                    child: _trainerAvatarUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              _trainerAvatarUrl,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(
                                    _trainerInitials,
                                    style: const TextStyle(
                                      color: Color(0xFF20B486),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                            ),
                          )
                        : Text(
                            _trainerInitials,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageTypePill(String label, int? usageTypeValue) {
    final isActive = _usageType == usageTypeValue;
    return InkWell(
      onTap: () {
        setState(() {
          _usageType = usageTypeValue;
          _currentPage = 1;
        });
        _fetchQuestions();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE6FFFA) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF20B486) : const Color(0xFF4B5563),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }
}
