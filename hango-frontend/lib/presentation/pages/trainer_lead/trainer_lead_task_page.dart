import 'package:flutter/material.dart';
import '../../../data/models/task_model.dart';
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
  String _selectedType = 'All type';

  final List<String> _taskTypes = ['All type', 'QUIZ', 'LESSON', 'EXAM', 'COURSE', 'SECTION'];

  // Assign Task Form State
  bool _isAssigningTask = false;
  final TextEditingController _assignContentController = TextEditingController();
  DateTime _assignDeadline = DateTime.now().add(const Duration(days: 7));
  String _assignType = 'QUIZ';

  List<Map<String, dynamic>> _trainers = [];
  String? _selectedCreatedById;
  String? _selectedReviewerId;
  String? _selectedImageBase64;
  String? _selectedImageName;

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

  Future<void> _handleImageUpload() async {
    try {
      final data = await pickImage();
      if (data != null && mounted) {
        setState(() {
          _selectedImageBase64 = data['base64'];
          _selectedImageName = data['name'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _assignContentController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    
    // Format dates to ISO if needed, but for now we just pass them if they exist
    String? fromDateStr = _fromDateController.text.isNotEmpty ? '${_fromDateController.text}T00:00:00Z' : null;
    String? toDateStr = _toDateController.text.isNotEmpty ? '${_toDateController.text}T23:59:59Z' : null;

    final result = await _taskService.getTasks(
      page: _currentPage,
      size: _pageSize,
      type: _selectedType,
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
              primary: Color(0xFF28B79B), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // format YYYY-MM-DD
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      _currentPage = 0;
      _fetchTasks();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
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
        return const Color(0xFFD1FAE5);
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

  void _showTaskDialog({TaskModel? task}) {
    // Basic Add Task Dialog
    final _contentController = TextEditingController(text: task?.content ?? '');
    final _assigneeIdController = TextEditingController(text: task?.assignedToId.toString() ?? '');
    String _formType = task?.type ?? 'QUIZ';
    DateTime _selectedDeadline = task?.deadline ?? DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task == null ? 'Add Task' : 'Edit Task',
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(labelText: 'Task Content'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _assigneeIdController,
                      decoration: const InputDecoration(labelText: 'Assignee ID (e.g. 2)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _formType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: ['QUIZ', 'LESSON', 'EXAM', 'COURSE', 'SECTION']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => _formType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Deadline: '),
                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDeadline,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => _selectedDeadline = picked);
                            }
                          },
                          child: Text(DateFormat('yyyy-MM-dd').format(_selectedDeadline)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28B79B)),
                  onPressed: () async {
                    if (_contentController.text.isEmpty || _assigneeIdController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                      return;
                    }

                    final data = {
                      'content': _contentController.text,
                      'assignedToId': int.tryParse(_assigneeIdController.text) ?? 0,
                      'type': _formType,
                      'deadline': _selectedDeadline.toIso8601String(),
                    };

                    Navigator.pop(context);
                    setState(() => _isLoading = true);

                    if (task == null) {
                      final res = await _taskService.createTask(data);
                      if (res['success']) {
                        _fetchTasks();
                      } else {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
                      }
                    }
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
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
              // Task Description
              const Text('Task Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
              const SizedBox(height: 8),
              TextField(
                controller: _assignContentController,
                decoration: InputDecoration(
                  hintText: 'Enter task content here...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Row 1
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Created By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedCreatedById,
                              hint: const Text('Select Creator', style: TextStyle(fontSize: 13)),
                              items: _trainers
                                .where((t) => (t['roles'] as List<dynamic>?)?.contains('TRAINER') ?? false)
                                .map((t) => DropdownMenuItem<String>(
                                value: t['id'].toString(), 
                                child: Text(t['fullName'] ?? '', style: const TextStyle(fontSize: 13))
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCreatedById = val);
                              },
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
                        const Text('Creation Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 13)),
                              const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                            ],
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
                        const Text('Reviewer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedReviewerId,
                              hint: const Text('Select Reviewer', style: TextStyle(fontSize: 13)),
                              items: _trainers.map((t) => DropdownMenuItem<String>(
                                value: t['id'].toString(), 
                                child: Text(t['fullName'] ?? '', style: const TextStyle(fontSize: 13))
                              )).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedReviewerId = val);
                              },
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
                        const Text('Review Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: _assignDeadline, firstDate: DateTime.now(), lastDate: DateTime(2030));
                            if (picked != null) setState(() => _assignDeadline = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

              // Row 2
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Course (Type)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _assignType,
                              items: ['QUIZ', 'LESSON', 'EXAM', 'COURSE', 'SECTION'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _assignType = val);
                              },
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
                        const Text('Section', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'English Grammar',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        const Text('Lesson', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Tenses & Conditionals',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        const Text('Total Questions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: InputDecoration(
                            hintText: '50',
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Image Upload
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid), // Dashed border usually requires an extra package
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(Icons.image_outlined, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        const Text('TASK IMAGE (OPTIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 1.0)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF28B79B)),
                    const SizedBox(height: 12),
                    const Text('Click to upload or drag and drop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                    const SizedBox(height: 4),
                    const Text('PNG, JPG or GIF (max. 5MB)', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    if (_selectedImageName != null) ...[
                      const SizedBox(height: 8),
                      Text('Selected: $_selectedImageName', style: const TextStyle(fontSize: 13, color: Color(0xFF28B79B), fontWeight: FontWeight.bold)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _handleImageUpload,
                      icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
                      label: Text(_selectedImageName == null ? 'Upload Image' : 'Change Image', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28B79B), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
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
                    child: const Text('Back', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_assignContentController.text.isEmpty || _selectedReviewerId == null || _selectedCreatedById == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
                        return;
                      }
                      if (_selectedReviewerId == _selectedCreatedById) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Creator and Reviewer cannot be the same person', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                        return;
                      }

                      final data = {
                        'content': _assignContentController.text,
                        'assignedToId': int.tryParse(_selectedReviewerId!) ?? 0,
                        'assignedById': int.tryParse(_selectedCreatedById!) ?? 0,
                        'type': _assignType,
                        'deadline': _assignDeadline.toIso8601String(),
                        if (_selectedImageBase64 != null) 'imageBase64': _selectedImageBase64,
                      };

                      setState(() => _isLoading = true);

                      final res = await _taskService.createTask(data);
                      if (res['success']) {
                        setState(() {
                          _isAssigningTask = false;
                          _assignContentController.clear();
                          _selectedCreatedById = null;
                          _selectedReviewerId = null;
                          _selectedImageBase64 = null;
                          _selectedImageName = null;
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
        
        // ── Top Bar (Search + Add) ───────────────────────────────────────────
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
                onSubmitted: (_) {
                  _currentPage = 0;
                  _fetchTasks();
                },
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _assignContentController.clear();
                setState(() {
                  _isAssigningTask = true;
                  _selectedCreatedById = null;
                  _selectedReviewerId = null;
                  _selectedImageBase64 = null;
                  _selectedImageName = null;
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

        // ── Filter Bar ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              // From Date
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
              // To Date
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
              const Spacer(),
              // Type Dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedType,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF374151), fontFamily: 'Outfit'),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedType = newValue);
                            _currentPage = 0;
                            _fetchTasks();
                          }
                        },
                        items: _taskTypes.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Data Table ───────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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
                    Expanded(flex: 3, child: Text('TASK CONTENT', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('ASSIGNEE', style: _headerStyle)),
                    Expanded(flex: 2, child: Text('REVIEWER', style: _headerStyle)),
                    Expanded(flex: 1, child: Text('TYPE', style: _headerStyle)),
                    Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
                    SizedBox(width: 80, child: Text('ACTIONS', style: _headerStyle)),
                  ],
                ),
              ),
              // Body
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
                              child: Text(task.content, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(task.assignedToName, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                          Expanded(flex: 2, child: Text(task.assignedByName, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
                          Expanded(
                            flex: 1, 
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  task.type, 
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1, 
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: PopupMenuButton<String>(
                                initialValue: task.status,
                                tooltip: 'Change Status',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusBgColor(task.status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        task.status, 
                                        style: TextStyle(fontSize: 11, color: _getStatusColor(task.status), fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.keyboard_arrow_down, size: 12, color: _getStatusColor(task.status)),
                                    ],
                                  ),
                                ),
                                onSelected: (newStatus) async {
                                  if (newStatus != task.status) {
                                    setState(() => _isLoading = true);
                                    final res = await _taskService.updateTaskStatus(task.id, newStatus);
                                    if (res['success']) {
                                      _fetchTasks();
                                    } else {
                                      setState(() => _isLoading = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
                                    }
                                  }
                                },
                                itemBuilder: (context) => ['ASSIGNED', 'IN_PROGRESS', 'DRAFT', 'REJECTED', 'COMPLETED']
                                    .map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80, 
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF28B79B)),
                                  onPressed: () => _showTaskDialog(task: task),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                  onPressed: () => _deleteTask(task.id),
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
              
              // ── Pagination ─────────────────────────────────────────────────
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
