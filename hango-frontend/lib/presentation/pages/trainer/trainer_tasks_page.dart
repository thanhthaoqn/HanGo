import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/model/trainer_task_model.dart';
import '../../../data/repositories/trainer_task_repository.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import '../../../utils/toast_helper.dart';

class TrainerTasksPage extends StatefulWidget {
  const TrainerTasksPage({super.key});

  @override
  State<TrainerTasksPage> createState() => _TrainerTasksPageState();
}

class _TrainerTasksPageState extends State<TrainerTasksPage> {
  final _authService = AuthService();
  final _taskRepository = TrainerTaskRepository();
  
  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';
  
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<TrainerTaskModel> _tasks = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  final int _pageSize = 10;
  
  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'All type';

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _fetchTasks();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    
    if (mounted) {
      setState(() {
        _trainerName = fullName;
        _trainerInitials = initials;
        _trainerAvatarUrl = '';
      });
    }
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _taskRepository.getTrainerTasks(
        fromDate: _fromDate,
        toDate: _toDate,
        type: _selectedType == 'All type' ? null : _selectedType,
        search: _searchController.text,
        page: _currentPage,
        size: _pageSize,
      );

      if (mounted) {
        setState(() {
          _tasks = response['tasks'];
          _totalPages = response['totalPages'];
          _totalElements = response['totalElements'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        ToastHelper.show(context, 'Failed to load tasks: $_errorMessage');
      }
    }
  }

  Future<void> _handleAcceptTask(int taskId) async {
    try {
      await _taskRepository.acceptTask(taskId);
      ToastHelper.show(context, 'Task accepted successfully');
      _fetchTasks();
    } catch (e) {
      ToastHelper.show(context, 'Failed to accept task: $e');
    }
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFilterSection(),
                        const SizedBox(height: 24),
                        _buildTasksTable(),
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
                  child: const Icon(Icons.school, size: 18, color: Color(0xFF20B486)),
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
          _buildSidebarItem(Icons.dashboard_outlined, 'Dashboard', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerDashboardPage()));
          }),
          _buildSidebarItem(Icons.book_outlined, 'Courses', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerCoursesPage()));
          }),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam'),
          _buildSidebarItem(Icons.people_outline, 'Learner'),
          _buildSidebarItem(Icons.question_answer_outlined, 'Question Bank', onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerQuestionBankPage()));
          }),
          _buildSidebarItem(Icons.task_alt_outlined, 'Task', isActive: true),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.help_outline, 'Help Center', onTap: () {
            ToastHelper.show(context, 'Help Center is under construction');
          }),
          _buildSidebarItem(Icons.logout, 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isActive = false, Color? color, VoidCallback? onTap}) {
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
              Icon(icon, color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenuIcon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (showMenuIcon)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const Text(
            'Task',
            style: TextStyle(
              color: Color(0xFF20B486),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF4B5563)),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Text(
                _trainerName,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF20B486),
                backgroundImage: _trainerAvatarUrl.isNotEmpty ? NetworkImage(_trainerAvatarUrl) : null,
                child: _trainerAvatarUrl.isEmpty
                    ? Text(_trainerInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final initialDate = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF20B486),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _fetchTasks();
    }
  }

  Widget _buildFilterSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search tasks...',
              border: InputBorder.none,
              icon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
            ),
            onSubmitted: (_) => _fetchTasks(),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('From', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fromDate != null ? _formatDate(_fromDate!) : 'Select Date', style: const TextStyle(color: Color(0xFF1F2937))),
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('To', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_toDate != null ? _formatDate(_toDate!) : 'Select Date', style: const TextStyle(color: Color(0xFF1F2937))),
                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        isDense: true,
                        items: ['All type', 'Quiz', 'Lesson', 'Exam', 'Course', 'Section'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedType = newValue;
                            });
                            _fetchTasks();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTasksTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 50, child: Text('NO.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)))),
                const Expanded(flex: 3, child: Text('TASK CONTENT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)))),
                const Expanded(child: Text('DEADLINE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)))),
                const Expanded(child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)))),
                const Expanded(child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)))),
                const Expanded(child: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151)), textAlign: TextAlign.center)),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator(color: Color(0xFF20B486))))
          else if (_tasks.isEmpty)
            const Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text('No tasks found.', style: TextStyle(color: Color(0xFF6B7280)))))
          else
            ..._tasks.asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text('${_currentPage * _pageSize + index + 1}', style: const TextStyle(color: Color(0xFF4B5563)))),
                    Expanded(flex: 3, child: Text(task.taskContent, style: const TextStyle(color: Color(0xFF1F2937)))),
                    Expanded(child: Text(_formatDate(task.deadline), style: const TextStyle(color: Color(0xFF4B5563)))),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: _buildBadge(task.type, isType: true))),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: _buildBadge(task.status, isType: false))),
                    Expanded(
                      child: Center(
                        child: _buildActionButton(task),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Display $_pageSize records/page', style: const TextStyle(color: Color(0xFF6B7280))),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0 ? () {
                          setState(() => _currentPage--);
                          _fetchTasks();
                        } : null,
                      ),
                      ...List.generate(_totalPages, (index) {
                        final isSelected = index == _currentPage;
                        return InkWell(
                          onTap: () {
                            setState(() => _currentPage = index);
                            _fetchTasks();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF20B486) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${index + 1}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF4B5563))),
                          ),
                        );
                      }),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < _totalPages - 1 ? () {
                          setState(() => _currentPage++);
                          _fetchTasks();
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {required bool isType}) {
    Color bgColor;
    Color textColor;

    if (isType) {
      bgColor = const Color(0xFFE6FFFA);
      textColor = const Color(0xFF20B486);
    } else {
      switch (text.toUpperCase()) {
        case 'ASSIGNED':
          bgColor = const Color(0xFFFEF3C7);
          textColor = const Color(0xFFD97706);
          break;
        case 'IN_PROGRESS':
          bgColor = const Color(0xFFDBEAFE);
          textColor = const Color(0xFF2563EB);
          break;
        case 'COMPLETED':
          bgColor = const Color(0xFFD1FAE5);
          textColor = const Color(0xFF059669);
          break;
        case 'REJECTED':
        case 'OVERDUE':
          bgColor = const Color(0xFFFEE2E2);
          textColor = const Color(0xFFDC2626);
          break;
        default:
          bgColor = const Color(0xFFF3F4F6);
          textColor = const Color(0xFF4B5563);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text.toUpperCase() == 'IN_PROGRESS' ? 'In Progress' : text[0].toUpperCase() + text.substring(1).toLowerCase(),
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildActionButton(TrainerTaskModel task) {
    if (task.status == 'ASSIGNED') {
      return ElevatedButton(
        onPressed: () => _handleAcceptTask(task.id),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF20B486),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Accept', style: TextStyle(fontSize: 13)),
      );
    } else if (task.status == 'IN_PROGRESS') {
      return OutlinedButton(
        onPressed: () {
          ToastHelper.show(context, 'Redirecting to task (Placeholder)');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF20B486),
          side: const BorderSide(color: Color(0xFF20B486)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Go to Task', style: TextStyle(fontSize: 13)),
      );
    } else {
      return Text(
        task.status == 'COMPLETED' ? 'Completed' : (task.status == 'REJECTED' ? 'Rejected' : '-'),
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontStyle: FontStyle.italic),
      );
    }
  }
}
