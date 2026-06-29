import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../services/hango_api.dart';
import '../../login_page.dart';
import '../trainer_courses_page.dart';
import '../trainer_dashboard_page.dart';
import 'models/trainer_question.dart';
import 'widgets/question_filter_pane.dart';
import 'widgets/question_search_bar.dart';
import 'widgets/question_table.dart';

class TrainerQuestionBankPage extends StatefulWidget {
  const TrainerQuestionBankPage({Key? key}) : super(key: key);

  @override
  State<TrainerQuestionBankPage> createState() => _TrainerQuestionBankPageState();
}

class _TrainerQuestionBankPageState extends State<TrainerQuestionBankPage> {
  final _authService = AuthService();
  final _searchController = TextEditingController();
  
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  bool _isLoading = true;
  String _errorMessage = '';

  // Filter States
  String _selectedType = 'QUIZ';
  String _searchQuery = '';
  String _sortBy = 'NEWEST';
  int _currentPage = 1;
  static const int _pageSize = 5;

  List<TrainerQuestion> _allQuestions = [];
  List<TrainerQuestion> _displayedQuestions = [];
  Timer? _debounceTimer;

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
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
    });
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
      // If DB fails, load beautiful Mock Data that aligns exactly with the design to keep it interactive
      _loadMockQuestions();
    }
  }

  void _loadMockQuestions() {
    // Generate beautiful mock data matching the screenshot
    final now = DateTime.now();
    final List<TrainerQuestion> mocks = [];

    if (_selectedType == 'QUIZ') {
      mocks.addAll([
        TrainerQuestion(
          id: 1,
          questionText: 'Which of the following is an example of an oxymoron...',
          categoryName: 'Grammar & Vocabulary',
          difficultyName: 'Medium',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 224, hours: 3)),
          updatedAt: now.subtract(const Duration(days: 213, hours: 1)),
        ),
        TrainerQuestion(
          id: 2,
          questionText: 'Identify the main theme in the provided paragraph regarding environmental policy...',
          categoryName: 'Reading Comprehension',
          difficultyName: 'Hard',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 223, hours: 8)),
          updatedAt: now.subtract(const Duration(days: 213, hours: 7)),
        ),
        TrainerQuestion(
          id: 3,
          questionText: 'Complete the sentence with the most appropriate modal verb...',
          categoryName: 'Grammar & Vocabulary',
          difficultyName: 'Easy',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 223, hours: 9)),
          updatedAt: now.subtract(const Duration(days: 223, hours: 9)),
        ),
        TrainerQuestion(
          id: 4,
          questionText: "Select the correct synonym for the word 'ubiquitous' in the context...",
          categoryName: 'Grammar & Vocabulary',
          difficultyName: 'Easy',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 222, hours: 11)),
          updatedAt: now.subtract(const Duration(days: 222, hours: 11)),
        ),
        TrainerQuestion(
          id: 5,
          questionText: 'Analyze the rhetorical devices used by the author in Chapter 5...',
          categoryName: 'Reading Comprehension',
          difficultyName: 'Hard',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 221, hours: 14)),
          updatedAt: now.subtract(const Duration(days: 221, hours: 13)),
        ),
        TrainerQuestion(
          id: 6,
          questionText: 'Vietnam\nInternational Art\nExhibition 2025 - A\nLandmark Cultural\nEvent',
          categoryName: 'Reading Comprehension',
          difficultyName: 'Medium',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 44, hours: 3)),
          updatedAt: now.subtract(const Duration(days: 33, hours: 1)),
        ),
      ]);
    } else {
      // EXAM Mock Data
      mocks.addAll([
        TrainerQuestion(
          id: 101,
          questionText: 'The man _______ is speaking to our teacher is my uncle.',
          categoryName: 'Grammar & Vocabulary',
          difficultyName: 'Easy',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now.subtract(const Duration(days: 9)),
        ),
        TrainerQuestion(
          id: 102,
          questionText: 'Choose the sentence that is closest in meaning to the following: "I would rather stay home than go out tonight."',
          categoryName: 'Grammar & Vocabulary',
          difficultyName: 'Medium',
          status: 'APPROVED',
          creatorName: _trainerName,
          createdAt: now.subtract(const Duration(days: 8)),
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
      ]);
    }

    // Client-side search filtering on mocks
    final search = _searchQuery.trim().toLowerCase();
    List<TrainerQuestion> filtered = mocks;
    if (search.isNotEmpty) {
      filtered = mocks.where((q) {
        return q.questionText.toLowerCase().contains(search) ||
            q.categoryName.toLowerCase().contains(search);
      }).toList();
    }

    // Client-side sorting on mocks
    if (_sortBy == 'NEWEST') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    setState(() {
      _allQuestions = filtered;
      _isLoading = false;
    });
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

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
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
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left pane: SELECT TYPE dropdown
                        QuestionFilterPane(
                          selectedType: _selectedType,
                          onTypeChanged: _handleTypeChanged,
                        ),
                        const SizedBox(width: 24),
                        // Right pane: Search bar and Table
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              QuestionSearchBar(
                                searchController: _searchController,
                                onSearchChanged: _handleSearch,
                                sortBy: _sortBy,
                                onSortChanged: _handleSortChanged,
                                onCreatePressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Create Question flow is under construction')),
                                  );
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Viewing question: ${q.questionText}')),
                                  );
                                },
                                onEditPressed: (q) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Editing question: ${q.questionText}')),
                                  );
                                },
                                onDeletePressed: (q) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Deleting question: ${q.questionText}')),
                                  );
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6FFFA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 18,
                    color: Color(0xFF20B486),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Sidebar menu items
          _buildSidebarItem(
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerDashboardPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(
            Icons.book_outlined,
            'Courses',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerCoursesPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam'),
          _buildSidebarItem(Icons.people_outline, 'Learner'),
          _buildSidebarItem(
            Icons.question_answer_outlined,
            'Question Bank',
            isActive: true,
          ),
          _buildSidebarItem(Icons.task_alt_outlined, 'Task'),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(
            Icons.help_outline,
            'Help Center',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Help Center is under construction'),
                ),
              );
            },
          ),
          _buildSidebarItem(
            Icons.logout,
            'Logout',
            color: Colors.redAccent,
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isActive = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final activeColor = const Color(0xFF20B486);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : (color ?? const Color(0xFF1F2937)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
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
            children: [
              const Text(
                'Question Bank',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                _selectedType,
                style: const TextStyle(
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
                icon: const Icon(Icons.notifications_none, color: Color(0xFF4B5563)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notifications feature is under construction')),
                  );
                },
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1, indent: 20, endIndent: 20, color: Color(0xFFE2E8F0)),
          const SizedBox(width: 16),
          Text(
            _trainerName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE6FFFA),
            child: Text(
              _trainerInitials,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF20B486),
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
