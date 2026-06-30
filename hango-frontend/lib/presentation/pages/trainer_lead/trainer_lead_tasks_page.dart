import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/trainer_lead_repository.dart';
import '../../../domain/model/trainer_lead_task_model.dart';
import 'widgets/trainer_lead_sidebar.dart';
import 'widgets/trainer_lead_header.dart';
import 'trainer_lead_assign_task_page.dart';

class TrainerLeadTasksPage extends StatefulWidget {
  const TrainerLeadTasksPage({super.key});

  @override
  State<TrainerLeadTasksPage> createState() => _TrainerLeadTasksPageState();
}

class _TrainerLeadTasksPageState extends State<TrainerLeadTasksPage> {
  final TrainerLeadRepository _repository = TrainerLeadRepository();
  
  String _userName = 'Thảo';
  String _userInitial = 'T';
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<TrainerLeadTaskModel> _tasks = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _pageSize = 10;
  
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

  Future<void> _loadUserInfo() async {
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
      _userName = fullName;
      _userInitial = initials;
    });
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final data = await _repository.getTasks(
        from: _fromDate,
        to: _toDate,
        type: _selectedType,
        search: _searchController.text,
        page: _currentPage,
        size: _pageSize,
      );
      
      setState(() {
        _tasks = (data['content'] as List).map((e) => TrainerLeadTaskModel.fromJson(e)).toList();
        _totalPages = data['totalPages'] ?? 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _currentPage = 0;
    _fetchTasks();
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Sidebar
          const TrainerLeadSidebar(activeMenu: 'Task'),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                TrainerLeadHeader(
                  title: 'Task',
                  userName: _userName,
                  userInitial: _userInitial,
                ),
                
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title & Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Task Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1b5c58),
                              ),
                            ),
                            
                            Row(
                              children: [
                                // Search bar
                                Container(
                                  width: 250,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    children: [
                                      Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onSubmitted: _onSearchChanged,
                                          decoration: InputDecoration(
                                            hintText: 'Search tasks...',
                                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Add Task Button
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const TrainerLeadAssignTaskPage()),
                                    );
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Task'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2ec4b6),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Filters row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              _buildDateFilter('From', _fromDate, true),
                              const SizedBox(width: 16),
                              _buildDateFilter('To', _toDate, false),
                              const Spacer(),
                              // Type Filter
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedType,
                                    icon: const Icon(Icons.filter_list, size: 16),
                                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedType = newValue;
                                        });
                                        _currentPage = 0;
                                        _fetchTasks();
                                      }
                                    },
                                    items: _types.map<DropdownMenuItem<String>>((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Data Table
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F8F7),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildHeaderCell('NO.', flex: 1),
                                      _buildHeaderCell('TASK CONTENT', flex: 4),
                                      _buildHeaderCell('ASSIGNEE', flex: 2),
                                      _buildHeaderCell('REVIEWER', flex: 2),
                                      _buildHeaderCell('TYPE', flex: 2),
                                      _buildHeaderCell('STATUS', flex: 2),
                                      _buildHeaderCell('ACTIONS', flex: 1, align: TextAlign.center),
                                    ],
                                  ),
                                ),
                                
                                // Table Body
                                Expanded(
                                  child: _isLoading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _errorMessage.isNotEmpty
                                          ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
                                          : _tasks.isEmpty
                                              ? const Center(child: Text('No tasks found.'))
                                              : ListView.separated(
                                                  itemCount: _tasks.length,
                                                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                                                  itemBuilder: (context, index) {
                                                    final task = _tasks[index];
                                                    return _buildDataRow(index, task);
                                                  },
                                                ),
                                ),
                                
                                // Pagination Footer
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Display', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('$_pageSize', style: const TextStyle(fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('records/page', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chevron_left, size: 20),
                                            onPressed: _currentPage > 0 ? () {
                                              setState(() => _currentPage--);
                                              _fetchTasks();
                                            } : null,
                                          ),
                                          // Simplified pagination (1, 2, 3...)
                                          for (int i = 0; i < (_totalPages > 5 ? 5 : _totalPages); i++)
                                            _buildPageNumber(i),
                                          if (_totalPages > 5) ...[
                                            const Text('...'),
                                            _buildPageNumber(_totalPages - 1),
                                          ],
                                          IconButton(
                                            icon: const Icon(Icons.chevron_right, size: 20),
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

  Widget _buildDateFilter(String label, DateTime? date, bool isFromDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectDate(context, isFromDate),
          child: Container(
            width: 130,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'DD/MM/YYYY',
                  style: TextStyle(
                    color: date != null ? Colors.black87 : Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Color(0xFF1b5c58),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataRow(int index, TrainerLeadTaskModel task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 1, child: Text('${index + 1 + (_currentPage * _pageSize)}', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 4, child: Text(task.taskContent, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(flex: 2, child: Text(task.assigneeName ?? 'N/A', style: const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(flex: 2, child: Text(task.reviewerName ?? 'N/A', style: const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildTypeBadge(task.type ?? 'Unknown'))),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(task.status ?? 'Unknown'))),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2ec4b6)), onTap: () {}),
                const SizedBox(width: 12),
                InkWell(child: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F8F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Color(0xFF1b5c58),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 12, color: Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _buildPageNumber(int pageIndex) {
    bool isActive = pageIndex == _currentPage;
    return GestureDetector(
      onTap: () {
        setState(() => _currentPage = pageIndex);
        _fetchTasks();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1b5c58) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${pageIndex + 1}',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
