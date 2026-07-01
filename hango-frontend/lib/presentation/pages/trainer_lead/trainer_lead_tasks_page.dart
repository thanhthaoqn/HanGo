import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/trainer_lead_repository.dart';
import '../../../domain/model/trainer_lead_task_model.dart';
import '../../../utils/toast_helper.dart';
import 'widgets/trainer_lead_sidebar.dart';
import 'widgets/trainer_lead_header.dart';
import 'trainer_lead_assign_task_page.dart';
import 'trainer_lead_task_detail_page.dart';

class TrainerLeadTasksPage extends StatefulWidget {
  const TrainerLeadTasksPage({super.key});

  @override
  State<TrainerLeadTasksPage> createState() => _TrainerLeadTasksPageState();
}

class _TrainerLeadTasksPageState extends State<TrainerLeadTasksPage> {
  final TrainerLeadRepository _repository = TrainerLeadRepository();
  
  String _userName = 'Trainer Lead';
  String _userInitial = 'T';
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<TrainerLeadTaskModel> _tasks = [];
  int _currentPage = 0;
  int _totalPages = 1;
  final int _pageSize = 10;
  
  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedType = 'All type';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _types = ['All type', 'Quiz', 'Lesson', 'Exam', 'Course', 'Section'];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchTasks();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer Lead';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _userName = fullName;
      _userInitial = initials;
    });
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final data = await _repository.getTasks(
        from: _fromDate,
        to: _toDate,
        type: _selectedType == 'All type' ? null : _selectedType,
        search: _searchController.text,
        page: _currentPage,
        size: _pageSize,
      );
      
      if (mounted) {
        setState(() {
          _tasks = (data['content'] as List).map((e) => TrainerLeadTaskModel.fromJson(e)).toList();
          _totalPages = data['totalPages'] ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        ToastHelper.showError(context, 'Failed to load tasks: $_errorMessage');
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now()),
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
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _currentPage = 0;
      _fetchTasks();
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
      drawer: !isDesktop ? const Drawer(child: TrainerLeadSidebar(activeMenu: 'Task')) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 250, child: TrainerLeadSidebar(activeMenu: 'Task')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrainerLeadHeader(
                  title: 'Task Management',
                  userName: _userName,
                  userInitial: _userInitial,
                ),
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

  Widget _buildFilterSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
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
                  onSubmitted: (_) {
                    _currentPage = 0;
                    _fetchTasks();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const TrainerLeadAssignTaskPage()),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
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
                        items: _types.map((String value) {
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
                            _currentPage = 0;
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
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('NO.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12))),
                Expanded(flex: 3, child: Text('TASK CONTENT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12))),
                Expanded(flex: 2, child: Text('ASSIGNEE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12))),
                Expanded(flex: 2, child: Text('REVIEWER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12))),
                Expanded(flex: 2, child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12))),
                Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12))),
                Expanded(flex: 1, child: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF374151), fontSize: 12), textAlign: TextAlign.center)),
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
                    Expanded(flex: 3, child: Text(task.taskContent, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text(task.assigneeName ?? 'N/A', style: const TextStyle(color: Color(0xFF4B5563)))),
                    Expanded(flex: 2, child: Text(task.reviewerName ?? 'N/A', style: const TextStyle(color: Color(0xFF4B5563)))),
                    Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildBadge(task.type ?? 'Unknown', isType: true))),
                    Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildBadge(task.status ?? 'Unknown', isType: false))),
                    Expanded(
                      flex: 1,
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
                      ...List.generate(_totalPages > 5 ? 5 : _totalPages, (index) {
                        final displayIndex = index; // Simplified logic for demo
                        final isSelected = displayIndex == _currentPage;
                        return InkWell(
                          onTap: () {
                            setState(() => _currentPage = displayIndex);
                            _fetchTasks();
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF20B486) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${displayIndex + 1}', style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF4B5563))),
                          ),
                        );
                      }),
                      if (_totalPages > 5) const Text('...'),
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
        case 'PENDING':
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
        text.toUpperCase() == 'IN_PROGRESS' ? 'In Progress' : (text.isNotEmpty ? text[0].toUpperCase() + text.substring(1).toLowerCase() : ''),
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildActionButton(TrainerLeadTaskModel task) {
    return IconButton(
      icon: const Icon(Icons.remove_red_eye, color: Color(0xFF20B486)),
      tooltip: 'View / Edit Detail',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrainerLeadTaskDetailPage(taskId: task.id),
          ),
        ).then((_) {
          _fetchTasks();
        });
      },
    );
  }
}
