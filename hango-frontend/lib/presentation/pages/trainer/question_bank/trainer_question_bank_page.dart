import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../services/hango_api.dart';
import '../../../../utils/config.dart';
import '../../course_manager/question_bank/course_manager_create_question_page.dart';
import '../trainer_profile_page.dart';
import '../../course_manager/question_bank/models/course_manager_question.dart';
import '../../course_manager/question_bank/widgets/question_search_bar.dart';
import '../../course_manager/question_bank/widgets/question_table.dart';
import '../../../widgets/trainer/trainer_sidebar.dart';

class CourseManagerQuestionBankPage extends StatefulWidget {
  final bool isEmbedded;
  const CourseManagerQuestionBankPage({super.key, this.isEmbedded = false});

  @override
  State<CourseManagerQuestionBankPage> createState() =>
      _CourseManagerQuestionBankPageState();
}

class _CourseManagerQuestionBankPageState
    extends State<CourseManagerQuestionBankPage> {
  final _authService = AuthService();
  final _searchController = TextEditingController();

  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';
  bool _isLoading = true;

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

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
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

    if (widget.isEmbedded) {
      return _buildBodyContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop
          ? const Drawer(child: TrainerSidebar(activeIndex: 3))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(width: 260, child: TrainerSidebar(activeIndex: 3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(child: _buildBodyContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    return SingleChildScrollView(
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
                      MaterialPageRoute(
                        builder: (context) =>
                            const CourseManagerCreateQuestionPage(),
                      ),
                    ).then((_) => _fetchQuestions());
                  },
                  onImportPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Excel Import flow is under construction',
                        ),
                      ),
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
                      MaterialPageRoute(
                        builder: (context) => CourseManagerCreateQuestionPage(
                          question: q,
                          isReadOnly: true,
                        ),
                      ),
                    );
                  },
                  onEditPressed: (q) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseManagerCreateQuestionPage(
                          question: q,
                          isEdit: true,
                        ),
                      ),
                    ).then((_) => _fetchQuestions());
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
                      }
                    } catch (e) {
                      setState(() {
                        q.status = oldStatus;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
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
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
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
                icon: const Icon(
                  Icons.notifications_none,
                  color: Color(0xFF4B5563),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notifications feature is under construction',
                      ),
                    ),
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
          const VerticalDivider(
            width: 1,
            indent: 20,
            endIndent: 20,
            color: Color(0xFFE2E8F0),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerProfilePage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
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
}
