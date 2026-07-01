import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/trainer_lead_repository.dart';
import '../../../utils/toast_helper.dart';
import '../../../domain/model/task_activity_model.dart';
import 'widgets/trainer_lead_sidebar.dart';
import 'widgets/trainer_lead_header.dart';
import 'trainer_lead_tasks_page.dart';

class TrainerLeadTaskDetailPage extends StatefulWidget {
  final int taskId;
  const TrainerLeadTaskDetailPage({super.key, required this.taskId});

  @override
  State<TrainerLeadTaskDetailPage> createState() => _TrainerLeadTaskDetailPageState();
}

class _TrainerLeadTaskDetailPageState extends State<TrainerLeadTaskDetailPage> {
  final TrainerLeadRepository _repository = TrainerLeadRepository();
  
  String _userName = 'Thảo';
  String _userInitial = 'T';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _reviewers = [];
  List<TaskActivityModel> _taskActivities = [];
  int? _selectedAssignee;
  int? _selectedReviewer;
  String? _selectedType;
  DateTime? _reviewDeadline;
  String? _selectedStatus;

  final List<String> _types = ['Quiz', 'Lesson', 'Exam', 'Course', 'Section'];
  final List<String> _statuses = ['ASSIGNED', 'IN_PROGRESS', 'PENDING', 'REJECTED', 'COMPLETED'];
  
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchData();
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

  Future<void> _fetchData() async {
    try {
      final trainers = await _repository.getTrainers();
      final reviewers = await _repository.getReviewers();
      final taskDetail = await _repository.getTaskDetail(widget.taskId);
      final activities = await _repository.getTaskActivities(widget.taskId);
      
      setState(() {
        _trainers = trainers;
        _reviewers = reviewers;
        _taskActivities = activities;
        
        _titleController.text = taskDetail['title'] ?? '';
        _descController.text = taskDetail['description'] ?? '';
        _selectedType = taskDetail['type'];
        if (_selectedType != null && !_types.contains(_selectedType)) {
          _types.add(_selectedType!);
        }
        
        _selectedAssignee = taskDetail['assigneeId'];
        _selectedReviewer = taskDetail['reviewerId'];
        
        _selectedStatus = taskDetail['status'];
        if (_selectedStatus != 'ASSIGNED') {
          _statuses.remove('ASSIGNED');
        }
        if (_selectedStatus != null && !_statuses.contains(_selectedStatus)) {
          _statuses.add(_selectedStatus!);
        }
        
        if (taskDetail['deadline'] != null) {
          _reviewDeadline = DateTime.parse(taskDetail['deadline']);
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Error loading task details: $e');
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reviewDeadline ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _reviewDeadline = picked;
      });
    }
  }

  void _showConfirmationDialog() {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty || 
        _selectedAssignee == null || _reviewDeadline == null || _selectedType == null || _selectedStatus == null) {
      ToastHelper.showError(context, 'Please fill all fields');
      return;
    }

    if (_selectedReviewer != null && _selectedAssignee == _selectedReviewer) {
      ToastHelper.showError(context, 'Assignee cannot be the same as Reviewer');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Update'),
          content: const Text('Are you sure you want to update this task?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ec4b6)),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                _submitTask();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitTask() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _repository.updateTask(widget.taskId, {
        'title': _titleController.text,
        'description': _descController.text,
        'type': _selectedType,
        'assigneeId': _selectedAssignee,
        'reviewerId': _selectedReviewer,
        'deadline': _reviewDeadline!.toIso8601String().split('.')[0],
        'status': _selectedStatus,
      });
      
      if (mounted) {
        ToastHelper.showSuccess(context, 'Task updated successfully');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TrainerLeadTasksPage()),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Error: $e');
      }
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
                  title: 'Task > Task Detail',
                  userName: _userName,
                  userInitial: _userInitial,
                ),
                
                // Content
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : DefaultTabController(
                        length: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Task Detail',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1b5c58),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const TabBar(
                                labelColor: Color(0xFF1b5c58),
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Color(0xFF1b5c58),
                                tabs: [
                                  Tab(text: "Detailed Information"),
                                  Tab(text: "Activity"),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildDetailedInformationTab(),
                                    _buildActivityTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildDetailedInformationTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task Title
                _buildLabel('Task Title'),
                _buildTextField(_titleController, 'Enter task title...'),
                
                const SizedBox(height: 12),

                // Task Description
                _buildLabel('Task Description'),
                Expanded(
                  child: _buildTextField(_descController, 'Enter task content here...', expands: true),
                ),

                const SizedBox(height: 12),

                // Row 1: Task Type, Deadline
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'Task Type',
                        _selectedType,
                        _types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        (val) => setState(() => _selectedType = val),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildDatePicker(
                        'Deadline',
                        _reviewDeadline,
                        () => _selectDate(context),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Row 2: Assignee, Reviewer
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'Assignee',
                        _selectedAssignee,
                        _trainers.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['fullName']))).toList(),
                        (val) => setState(() => _selectedAssignee = val),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildDropdown(
                        'Reviewer',
                        _selectedReviewer,
                        _reviewers.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['fullName']))).toList(),
                        (val) => setState(() => _selectedReviewer = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Action Buttons
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 250,
                child: _buildDropdown(
                  'Status',
                  _selectedStatus,
                  _statuses.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  (val) => setState(() => _selectedStatus = val),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const TrainerLeadTasksPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _showConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ec4b6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('UPDATE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Timeline History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _taskActivities.length,
                    itemBuilder: (context, index) {
                      final activity = _taskActivities[index];
                      return _buildTimelineItem(activity, isLast: index == _taskActivities.length - 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Task Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _selectedStatus == 'COMPLETED' ? 1.0 : (_selectedStatus == 'ASSIGNED' ? 0.0 : 0.5),
                              strokeWidth: 10,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF2ec4b6),
                            ),
                          ),
                          Text(
                            _selectedStatus == 'COMPLETED' ? '100%' : (_selectedStatus == 'ASSIGNED' ? '0%' : '50%'),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(child: Text('Based on subtasks (mocked)', style: TextStyle(color: Colors.grey, fontSize: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assigned Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildMemberRow('Assignee', _selectedAssignee != null ? _trainers.firstWhere((e) => e['id'] == _selectedAssignee, orElse: () => {'fullName': 'Unknown'})['fullName'] : 'None', Colors.blue),
                    const SizedBox(height: 12),
                    _buildMemberRow('Reviewer', _selectedReviewer != null ? _reviewers.firstWhere((e) => e['id'] == _selectedReviewer, orElse: () => {'fullName': 'Unknown'})['fullName'] : 'None', Colors.purple),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(TaskActivityModel activity, {bool isLast = false}) {
    Color iconColor = Colors.blue;
    IconData iconData = Icons.circle;
    if (activity.actionType == 'COMPLETED') {
      iconColor = Colors.green;
      iconData = Icons.check_circle;
    } else if (activity.actionType == 'REJECTED') {
      iconColor = Colors.red;
      iconData = Icons.cancel;
    } else if (activity.actionType == 'TASK_INITIATED') {
      iconColor = Colors.orange;
      iconData = Icons.play_circle_filled;
    } else if (activity.actionType == 'UPDATED') {
      iconColor = Colors.purple;
      iconData = Icons.edit;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 24, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    activity.actionType,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${activity.createdAt.day}/${activity.createdAt.month}/${activity.createdAt.year} ${activity.createdAt.hour}:${activity.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                  children: [
                    TextSpan(text: '${activity.userName} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: activity.description ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberRow(String role, String name, Color color) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.1),
          child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(role, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int? maxLines = 1, bool expands = false}) {
    return TextField(
      controller: controller,
      maxLines: expands ? null : maxLines,
      expands: expands,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildDropdown(String label, dynamic value, List<DropdownMenuItem<dynamic>> items, Function(dynamic) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              isExpanded: true,
              value: value,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
              hint: Text('Select $label', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap, {bool disabled = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        InkWell(
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: disabled ? Colors.grey.shade100 : Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'Select Date',
                  style: TextStyle(
                    color: date != null ? Colors.black87 : Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
