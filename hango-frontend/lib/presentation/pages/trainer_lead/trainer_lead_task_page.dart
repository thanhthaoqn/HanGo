import 'package:flutter/material.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/task_activity_model.dart';
import '../../../data/services/task_service.dart';
import 'package:intl/intl.dart';
import '../../../utils/image_picker.dart';

class TrainerLeadTaskPage extends StatefulWidget {
  const TrainerLeadTaskPage({super.key});

  @override
  State<TrainerLeadTaskPage> createState() => _TrainerLeadTaskPageState();
}

class _TrainerLeadTaskPageState extends State<TrainerLeadTaskPage> {
  final TaskService _taskService = TaskService();
  bool _isLoading = true;
  List<TaskModel> _tasks = [];
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;
  final int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  // Assign Task Form State
  bool _isAssigningTask = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();
  DateTime _assignDeadline = DateTime.now().add(const Duration(days: 7));

  List<Map<String, dynamic>> _trainers = [];
  String? _selectedAssigneeId;
  String _selectedType = 'QUIZ';
  String? _selectedReviewerId;
  final List<String> _taskTypes = ['COURSE', 'EXAM', 'QUIZ', 'LESSON', 'SECTION'];

  TaskModel? _editingTask;
  DateTime? _editDeadline;
  String? _editStatus;
  String? _editReviewerId;
  int _selectedTabIndex = 0;
  List<TaskActivityModel> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    _fetchTrainers();
  }

  Future<void> _fetchTrainers() async {
    final res = await _taskService.getTrainers();
    if (res['success']) {
      if (mounted) {
        setState(() {
          _trainers = List<Map<String, dynamic>>.from(res['trainers']);
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    
    String? fromDateStr = _fromDateController.text.isNotEmpty ? '${_fromDateController.text}T00:00:00Z' : null;
    String? toDateStr = _toDateController.text.isNotEmpty ? '${_toDateController.text}T23:59:59Z' : null;

    final result = await _taskService.getTasks(
      page: _currentPage,
      size: _pageSize,
      search: _searchController.text.trim(),
      fromDate: fromDateStr,
      toDate: toDateStr,
    );

    if (mounted) {
      if (result['success']) {
        setState(() {
          _tasks = result['tasks'];
          _totalPages = result['totalPages'];
          _totalElements = result['totalElements'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to load tasks')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF28B79B),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      _currentPage = 0;
      _fetchTasks();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'SUBMITTED':
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      case 'REJECTED':
        return const Color(0xFFEF4444);
      case 'DRAFT':
        return const Color(0xFF6B7280);
      case 'ASSIGNED':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'APPROVED':
        return const Color(0xFFD1FAE5);
      case 'SUBMITTED':
      case 'IN_PROGRESS':
        return const Color(0xFFFEF3C7);
      case 'REJECTED':
        return const Color(0xFFFEE2E2);
      case 'DRAFT':
        return const Color(0xFFF3F4F6);
      case 'ASSIGNED':
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  void _deleteTask(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final res = await _taskService.deleteTask(id);
      if (res['success']) {
        _fetchTasks();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAssigningTask) {
      return _buildAssignTaskView();
    }
    if (_editingTask != null) {
      return _buildTaskDetailView();
    }
    return _buildTaskListView();
  }

  Widget _buildAssignTaskView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _isAssigningTask = false),
              child: const Text('Task', style: TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const Text('Assign Task', style: TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Assign Task',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Task Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedType,
                              onChanged: (String? newValue) {
                                if (newValue != null) setState(() => _selectedType = newValue);
                              },
                              items: _taskTypes.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 13)));
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: _assignDeadline, firstDate: DateTime.now(), lastDate: DateTime(2030));
                            if (picked != null) setState(() => _assignDeadline = picked);
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd/MM/yyyy').format(_assignDeadline), style: const TextStyle(fontSize: 13)),
                                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text('Task Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter task title...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Task Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter task description here...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assignee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Select an Assignee', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                              value: _selectedAssigneeId,
                              onChanged: (String? newValue) {
                                setState(() => _selectedAssigneeId = newValue);
                              },
                              items: _trainers.where((t) => (t['roles'] as List).contains('TRAINER')).map<DropdownMenuItem<String>>((trainer) {
                                return DropdownMenuItem<String>(
                                  value: trainer['id'].toString(),
                                  child: Text(trainer['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reviewer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: const Text('Select a Reviewer', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                              value: _selectedReviewerId,
                              onChanged: (String? newValue) {
                                setState(() => _selectedReviewerId = newValue);
                              },
                              items: _trainers.map<DropdownMenuItem<String>>((trainer) {
                                return DropdownMenuItem<String>(
                                  value: trainer['id'].toString(),
                                  child: Text(trainer['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _isAssigningTask = false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_titleController.text.isEmpty || _selectedAssigneeId == null || _selectedReviewerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields and select an assignee and reviewer.')));
                        return;
                      }

                      if (_selectedAssigneeId == _selectedReviewerId) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignee and Reviewer cannot be the same.')));
                        return;
                      }

                      final data = {
                        'title': _titleController.text,
                        'description': _descriptionController.text,
                        'dueDate': _assignDeadline.toIso8601String(),
                        'assigneeId': int.tryParse(_selectedAssigneeId!),
                        'type': _selectedType,
                        'reviewerId': int.tryParse(_selectedReviewerId!),
                      };

                      setState(() => _isLoading = true);

                      final res = await _taskService.createTask(data);
                      if (res['success']) {
                        setState(() {
                          _isAssigningTask = false;
                          _titleController.clear();
                          _descriptionController.clear();
                          _selectedAssigneeId = null;
                          _selectedType = 'QUIZ';
                          _selectedReviewerId = null;
                        });
                        _fetchTasks();
                      } else {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('ASSIGN TASK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _fetchTaskActivities(int taskId) async {
    final res = await _taskService.getTaskActivities(taskId);
    if (res['success']) {
      final List<dynamic> activitiesJson = res['activities'] ?? [];
      setState(() {
        _activities = activitiesJson.map((json) => TaskActivityModel.fromJson(json)).toList();
      });
    } else {
      setState(() {
        _activities = [];
      });
    }
  }

  Widget _buildActivityTab(TaskModel task, dynamic assignee) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar (Progress and Members)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaskProgress(assignee?.status ?? 'ASSIGNED'),
                const SizedBox(height: 24),
                _buildAssignedMembers(task, assignee),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Right Column (Timeline History)
          Expanded(
            flex: 2,
            child: _buildTimelineHistory(),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskProgress(String status) {
    int percentage = 0;
    switch (status) {
      case 'ASSIGNED': percentage = 0; break;
      case 'IN_PROGRESS': percentage = 50; break;
      case 'SUBMITTED': percentage = 80; break;
      case 'APPROVED': percentage = 100; break;
      case 'REJECTED': percentage = 30; break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TASK PROGRESS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6EE7B7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(status.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
              ),
              Text('$percentage%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFD1FAE5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedMembers(TaskModel task, dynamic assignee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ASSIGNED MEMBERS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          if (assignee != null)
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF10B981),
                  child: Text(assignee.creatorName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assignee.creatorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const Text('Trainer - Assignee', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (assignee?.reviewerName != null)
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF3B82F6),
                  child: Text(assignee.reviewerName![0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assignee.reviewerName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const Text('Trainer - Reviewer', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Timeline History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          ],
        ),
        const SizedBox(height: 24),
        if (_activities.isEmpty)
          const Text('No activities found.', style: TextStyle(color: Color(0xFF6B7280))),
        ..._activities.map((activity) {
          bool isCritical = activity.action.toLowerCase().contains('reject') || activity.action.toLowerCase().contains('error');
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isCritical ? Colors.red : const Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 50, // Line to next dot, simplified
                      color: const Color(0xFFE5E7EB),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(DateFormat('HH:mm - MMMM dd, yyyy').format(activity.timestamp), style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF9CA3AF))),
                          const SizedBox(width: 8),
                          Text(activity.userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(activity.details ?? activity.action, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(activity.action, style: TextStyle(fontSize: 10, color: isCritical ? Colors.red : const Color(0xFF065F46), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTaskDetailView() {
    final task = _editingTask!;
    final assignee = task.assignees.isNotEmpty ? task.assignees.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _editingTask = null),
              child: const Text('Task Management', style: TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            const Text('Task Detail', style: TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Task Detail',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tabs
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: _selectedTabIndex == 0 ? const Color(0xFF28B79B) : Colors.transparent, width: 2)),
                          ),
                          child: Center(
                            child: Text('Detailed Information', style: TextStyle(color: _selectedTabIndex == 0 ? const Color(0xFF28B79B) : const Color(0xFF6B7280), fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedTabIndex = 1);
                          if (_activities.isEmpty) {
                            _fetchTaskActivities(task.id);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: _selectedTabIndex == 1 ? const Color(0xFF28B79B) : Colors.transparent, width: 2)),
                          ),
                          child: Center(
                            child: Text('Activity', style: TextStyle(color: _selectedTabIndex == 1 ? const Color(0xFF28B79B) : const Color(0xFF6B7280), fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_selectedTabIndex == 0)
                Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Task Content', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Text(task.title, style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937))),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Task Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF3F4F6)),
                                alignment: Alignment.centerLeft,
                                child: Text(task.type ?? 'N/A', style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _editDeadline ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() => _editDeadline = date);
                                  }
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd/MM/yyyy').format(_editDeadline ?? DateTime.now()), style: const TextStyle(fontSize: 13)),
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
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
                              const Text('Assignee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF3F4F6)),
                                alignment: Alignment.centerLeft,
                                child: Text(assignee?.creatorName ?? 'N/A', style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reviewer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  bool canEditReviewer = DateTime.now().isBefore(task.dueDate) && assignee?.status != 'SUBMITTED';
                                  if (canEditReviewer) {
                                    return Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _trainers.any((t) => t['id'].toString() == _editReviewerId) ? _editReviewerId : null,
                                          isExpanded: true,
                                          hint: const Text('Select Reviewer', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                                          items: _trainers.map<DropdownMenuItem<String>>((trainer) {
                                            return DropdownMenuItem<String>(
                                              value: trainer['id'].toString(),
                                              child: Text(trainer['fullName'] ?? 'Unknown', style: const TextStyle(fontSize: 13)),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _editReviewerId = val);
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF3F4F6)),
                                      alignment: Alignment.centerLeft,
                                      child: Text(assignee?.reviewerName ?? 'N/A', style: const TextStyle(fontSize: 13)),
                                    );
                                  }
                                }
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _editStatus,
                                    isExpanded: true,
                                    items: ['ASSIGNED', 'IN_PROGRESS', 'SUBMITTED', 'REJECTED', 'APPROVED'].map((status) {
                                      return DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 13)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _editStatus = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: TextField(
                        controller: _editDescriptionController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter task description',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                        ),
                        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => setState(() => _editingTask = null),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                side: const BorderSide(color: Color(0xFFE5E7EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Back', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () async {
                                final assignee = task.assignees.isNotEmpty ? task.assignees.first : null;
                                final newReviewerId = _editReviewerId != null ? int.tryParse(_editReviewerId!) : assignee?.reviewerId;
                                if (newReviewerId != null && newReviewerId == assignee?.creatorId) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignee and Reviewer cannot be the same.')));
                                  return;
                                }

                                final data = {
                                  'title': task.title,
                                  'description': _editDescriptionController.text,
                                  'type': task.type,
                                  'dueDate': _editDeadline?.toIso8601String() ?? task.dueDate.toIso8601String(),
                                  'assigneeId': assignee?.creatorId,
                                  'reviewerId': newReviewerId,
                                };
                                
                                final updateRes = await _taskService.updateTask(task.id, data);
                                if (updateRes['success'] == true) {
                                  if (_editStatus != null && _editStatus != assignee?.status) {
                                    await _taskService.updateTaskStatus(task.id, _editStatus!);
                                  }
                                  setState(() => _editingTask = null);
                                  _fetchTasks();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated successfully')));
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: ${updateRes['message']}')));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF28B79B),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ) // Closes Padding
              else
                _buildActivityTab(task, assignee),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Task Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 300,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                onSubmitted: (_) {
                  _currentPage = 0;
                  _fetchTasks();
                },
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, height: 1.0),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _titleController.clear();
                _descriptionController.clear();
                setState(() {
                  _isAssigningTask = true;
                  _selectedAssigneeId = null;
                  _selectedType = 'QUIZ';
                  _selectedReviewerId = null;
                });
              },
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text('Add Task', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('From', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _selectDate(context, _fromDateController),
                    child: Container(
                      width: 140,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fromDateController.text.isEmpty ? 'YYYY-MM-DD' : _fromDateController.text,
                              style: TextStyle(color: _fromDateController.text.isEmpty ? Colors.grey : Colors.black, fontSize: 13)),
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('To', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _selectDate(context, _toDateController),
                    child: Container(
                      width: 140,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_toDateController.text.isEmpty ? 'YYYY-MM-DD' : _toDateController.text,
                              style: TextStyle(color: _toDateController.text.isEmpty ? Colors.grey : Colors.black, fontSize: 13)),
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 40, child: Text('NO.', style: _headerStyle)),
                    Expanded(flex: 3, child: Text('TITLE', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('ASSIGNEE', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('REVIEWER', style: _headerStyle)),
                    Expanded(flex: 1, child: Text('TYPE', style: _headerStyle)),
                    Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
                    Expanded(flex: 1, child: Text('DEADLINE', style: _headerStyle)),
                    SizedBox(width: 50, child: Text('ACTION', style: _headerStyle)),
                  ],
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
                )
              else if (_tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No tasks found.', style: TextStyle(color: Color(0xFF6B7280)))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tasks.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text('${index + 1 + (_currentPage * _pageSize)}', style: const TextStyle(fontSize: 13))),
                          Expanded(
                            flex: 3, 
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(task.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ),
                          Expanded(
                            flex: 2, 
                            child: Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(color: _getStatusColor(task.assignees.isNotEmpty ? task.assignees.first.status : 'ASSIGNED'), shape: BoxShape.circle),
                                ),
                                Expanded(child: Text(task.assignees.isNotEmpty ? task.assignees.first.creatorName : 'N/A', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ],
                            )
                          ),
                          Expanded(
                            flex: 2, 
                            child: Text(task.assignees.isNotEmpty && task.assignees.first.reviewerName != null ? task.assignees.first.reviewerName! : 'N/A', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
                          ),
                          Expanded(flex: 1, child: Text(task.type ?? 'N/A', style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                          Expanded(
                            flex: 1, 
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(task.assignees.isNotEmpty ? task.assignees.first.status : 'ASSIGNED').withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                task.assignees.isNotEmpty ? task.assignees.first.status.replaceAll('_', ' ') : 'ASSIGNED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(task.assignees.isNotEmpty ? task.assignees.first.status : 'ASSIGNED'),
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          ),
                          Expanded(flex: 1, child: Text(DateFormat('dd/MM/yyyy').format(task.dueDate), style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                          SizedBox(
                            width: 50, 
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6B7280)),
                                  onPressed: () {
                                    setState(() {
                                      _editingTask = task;
                                      _selectedTabIndex = 0;
                                      _activities = [];
                                      _editDescriptionController.text = task.description;
                                      _editDeadline = task.dueDate;
                                      _editStatus = task.assignees.isNotEmpty ? task.assignees.first.status : 'ASSIGNED';
                                      _editReviewerId = task.assignees.isNotEmpty ? task.assignees.first.reviewerId?.toString() : null;
                                    });
                                    _fetchTaskActivities(task.id);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            )
                          ),
                        ],
                      ),
                    );
                  },
                ),
              
              if (!_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Display', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('$_pageSize', style: const TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          const Text('records/page', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
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
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF28B79B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${_currentPage + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('of $_totalPages', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
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
      ],
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: Color(0xFF6B7280),
  letterSpacing: 0.5,
);
