import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/trainer_lead_repository.dart';
import '../../../utils/toast_helper.dart';
import 'widgets/trainer_lead_sidebar.dart';
import 'widgets/trainer_lead_header.dart';
import 'trainer_lead_tasks_page.dart';

class TrainerLeadAssignTaskPage extends StatefulWidget {
  const TrainerLeadAssignTaskPage({super.key});

  @override
  State<TrainerLeadAssignTaskPage> createState() => _TrainerLeadAssignTaskPageState();
}

class _TrainerLeadAssignTaskPageState extends State<TrainerLeadAssignTaskPage> {
  final TrainerLeadRepository _repository = TrainerLeadRepository();
  
  String _userName = 'Thảo';
  String _userInitial = 'T';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _reviewers = [];
  int? _selectedAssignee;
  int? _selectedReviewer;
  String? _selectedType;
  DateTime? _reviewDeadline;
  
  final DateTime _creationDate = DateTime.now();

  final List<String> _types = ['Quiz', 'Lesson', 'Exam', 'Course', 'Section'];
  bool _isLoadingTrainers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchTrainers();
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

  Future<void> _fetchTrainers() async {
    try {
      final trainers = await _repository.getTrainers();
      final reviewers = await _repository.getReviewers();
      setState(() {
        _trainers = trainers;
        _reviewers = reviewers;
        _isLoadingTrainers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTrainers = false;
      });
      // Handle error natively
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
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
        _selectedAssignee == null || _selectedReviewer == null || _reviewDeadline == null || _selectedType == null) {
      ToastHelper.showError(context, 'Please fill all fields');
      return;
    }

    if (_selectedAssignee == _selectedReviewer) {
      ToastHelper.showError(context, 'Assignee cannot be the same as Reviewer');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Assign Task'),
          content: const Text('Are you sure you want to assign this task?'),
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
      await _repository.createTask({
        'title': _titleController.text,
        'description': _descController.text,
        'type': _selectedType,
        'assigneeId': _selectedAssignee,
        'reviewerId': _selectedReviewer,
        'reviewDeadline': _reviewDeadline!.toIso8601String(),
      });
      
      if (mounted) {
        ToastHelper.showSuccess(context, 'Task assigned successfully');
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
                  title: 'Task > Assign Task',
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
                        const Text(
                          'Assign Task',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1b5c58),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            padding: const EdgeInsets.all(24),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Task Title
                                  _buildLabel('Task Title'),
                                  _buildTextField(_titleController, 'Enter task title...'),
                                  
                                  const SizedBox(height: 20),

                                  // Task Description
                                  _buildLabel('Task Description'),
                                  _buildTextField(_descController, 'Enter task content here...', maxLines: 4),

                                  const SizedBox(height: 20),

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

                                  const SizedBox(height: 20),

                                  // Row 2: Assignee, Reviewer
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDropdown(
                                          'Assignee',
                                          _selectedAssignee,
                                          _isLoadingTrainers ? [] : _trainers.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['fullName']))).toList(),
                                          (val) => setState(() => _selectedAssignee = val),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: _buildDropdown(
                                          'Reviewer',
                                          _selectedReviewer,
                                          _isLoadingTrainers ? [] : _reviewers.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['fullName']))).toList(),
                                          (val) => setState(() => _selectedReviewer = val),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
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
                                    : const Text('ASSIGN TASK', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
