import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../services/hango_api.dart';
import '../../../../utils/config.dart';
import '../../widgets/shared_header.dart';
import '../trainer/question_bank/widgets/question_search_bar.dart';
import '../trainer/question_bank/widgets/question_table.dart';
import '../trainer/question_bank/trainer_create_question_page.dart';
import '../trainer/question_bank/models/trainer_question.dart';
import '../../widgets/course_manager_sidebar.dart';

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

  List<TrainerQuestion> _allQuestions = [];
  List<TrainerQuestion> _displayedQuestions = [];
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
                                    MaterialPageRoute(builder: (context) => const TrainerCreateQuestionPage()),
                                  ).then((_) => _fetchQuestions());
                                },
                                onImportPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Excel Import flow is under construction')),
                                  );
                                },
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
                                    MaterialPageRoute(builder: (context) => TrainerCreateQuestionPage(
                                      question: q,
                                      isReadOnly: true,
                                    )),
                                  );
                                },
                                onEditPressed: (q) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => TrainerCreateQuestionPage(
                                      question: q,
                                      isEdit: true,
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
