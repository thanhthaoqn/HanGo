import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/trainer_task_repository.dart';
import '../../../utils/toast_helper.dart';
import '../../../domain/model/task_activity_model.dart';
import 'trainer_tasks_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import '../login_page.dart';

class TrainerTaskDetailPage extends StatefulWidget {
  final int taskId;
  const TrainerTaskDetailPage({super.key, required this.taskId});

  @override
  State<TrainerTaskDetailPage> createState() => _TrainerTaskDetailPageState();
}

class _TrainerTaskDetailPageState extends State<TrainerTaskDetailPage> {
  final TrainerTaskRepository _repository = TrainerTaskRepository();
  
  String _userName = 'Trainer';
  String _userInitial = 'T';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<TaskActivityModel> _taskActivities = [];
  int? _selectedAssignee;
  String? _assigneeName;
  int? _selectedReviewer;
  String? _reviewerName;
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
    final fullName = prefs.getString('user_fullname') ?? 'Trainer';
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
      final taskDetail = await _repository.getTaskDetail(widget.taskId);
      final activities = await _repository.getTaskActivities(widget.taskId);
      
      setState(() {
        _taskActivities = activities;
        
        _titleController.text = taskDetail['title'] ?? '';
        _descController.text = taskDetail['description'] ?? '';
        _selectedType = taskDetail['type'];
        if (_selectedType != null && !_types.contains(_selectedType)) {
          _types.add(_selectedType!);
        }
        
        _selectedAssignee = taskDetail['assigneeId'];
        _assigneeName = taskDetail['assigneeName'];
        _selectedReviewer = taskDetail['reviewerId'];
        _reviewerName = taskDetail['reviewerName'];
        
        _selectedStatus = taskDetail['status'];
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

  Future<void> _handleAcceptTask() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Accept Task'),
          content: const Text('Are you sure you want to accept this task?'),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF20B486)),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                _performAcceptTask();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performAcceptTask() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _repository.acceptTask(widget.taskId);
      if (mounted) {
        ToastHelper.showSuccess(context, 'Task accepted successfully');
        _fetchData(); // Reload detail to show Go to Task
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Error accepting task: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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
          if (MediaQuery.of(context).size.width >= 768) SizedBox(width: 250, child: _buildSidebar(context)),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Header
                _buildHeader(context, MediaQuery.of(context).size.width < 768),
                
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
                _buildTextField(_titleController, 'Task title...', readOnly: true),
                
                const SizedBox(height: 12),

                // Task Description
                _buildLabel('Task Description'),
                Expanded(
                  child: _buildTextField(_descController, 'Task content...', expands: true, readOnly: true),
                ),

                const SizedBox(height: 12),

                // Row 1: Task Type, Deadline
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'Task Type',
                        _selectedType,
                        _selectedType != null ? [DropdownMenuItem(value: _selectedType, child: Text(_selectedType!))] : [],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildDatePicker(
                        'Deadline',
                        _reviewDeadline,
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
                        _selectedAssignee != null ? [DropdownMenuItem(value: _selectedAssignee, child: Text(_assigneeName ?? 'Unknown'))] : [],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildDropdown(
                        'Reviewer',
                        _selectedReviewer,
                        _selectedReviewer != null ? [DropdownMenuItem(value: _selectedReviewer, child: Text(_reviewerName ?? 'Unknown'))] : [],
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
                  _selectedStatus != null ? [DropdownMenuItem(value: _selectedStatus, child: Text(_selectedStatus!))] : [],
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const TrainerTasksPage()),
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
                  if (_selectedStatus == 'ASSIGNED') ...[
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleAcceptTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20B486),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Accept Task', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ] else if (_selectedStatus == 'IN_PROGRESS') ...[
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        ToastHelper.show(context, 'Redirecting to task (Placeholder)');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Go to Task', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
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
                    _buildMemberRow('Assignee', _assigneeName ?? 'Unknown', Colors.blue),
                    const SizedBox(height: 12),
                    _buildMemberRow('Reviewer', _reviewerName ?? 'Unknown', Colors.purple),
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

  Widget _buildTextField(TextEditingController controller, String hint, {int? maxLines = 1, bool expands = false, bool readOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
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
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        filled: readOnly,
      ),
    );
  }

  Widget _buildDropdown(String label, dynamic value, List<DropdownMenuItem<dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              isExpanded: true,
              value: value,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
              hint: Text(value != null ? value.toString() : 'Select $label', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              items: items,
              onChanged: null, // Disabled
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}' : 'Select Date',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ],
    );
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    await prefs.remove('user_fullname');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
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
          _buildSidebarItem(Icons.task_alt_outlined, 'Task', isActive: true, onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TrainerTasksPage()));
          }),
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          if (showMenuIcon)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF4B5563)),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            backgroundColor: const Color(0xFF20B486),
            child: Text(
              _userInitial,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _userName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}
