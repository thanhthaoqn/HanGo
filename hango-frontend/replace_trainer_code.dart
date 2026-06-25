import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  var content = file.readAsStringSync();
  
  // 1. Remove state variables
  content = content.replaceFirst('''  // Assign Task Form State
  bool _isAssigningTask = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();
  DateTime _assignDeadline = DateTime.now().add(const Duration(days: 7));

  List<Map<String, dynamic>> _trainers = [];
  String? _selectedAssigneeId;
  String _selectedType = 'QUIZ';
  String? _selectedReviewerId;
  final List<String> _taskTypes = ['COURSE', 'EXAM', 'QUIZ', 'LESSON', 'SECTION'];''', '''  final TextEditingController _editDescriptionController = TextEditingController();''');
  
  // 2. Remove fetchTrainers call
  content = content.replaceFirst('''    _fetchTasks();
    _fetchTrainers();''', '''    _fetchTasks();''');
    
  // 3. Remove _titleController dispose
  content = content.replaceFirst('''    _titleController.dispose();
    _descriptionController.dispose();
''', '');

  // 4. Modify build
  content = content.replaceFirst('''  @override
  Widget build(BuildContext context) {
    if (_isAssigningTask) {
      return _buildAssignTaskView();
    }
    if (_editingTask != null) {''', '''  @override
  Widget build(BuildContext context) {
    if (_editingTask != null) {''');

  // 5. Remove _fetchTasks and add _acceptTask
  final fetchTasksStart = content.indexOf('  Future<void> _fetchTasks() async {');
  final fetchTasksEnd = content.indexOf('  Future<void> _fetchTrainers() async {');
  if (fetchTasksStart != -1 && fetchTasksEnd != -1) {
    content = content.substring(0, fetchTasksStart) + r'''
  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    final res = await _taskService.getTasks(
      page: _currentPage,
      size: _pageSize,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      fromDate: _fromDateController.text.isNotEmpty ? 'T00:00:00' : null,
      toDate: _toDateController.text.isNotEmpty ? 'T23:59:59' : null,
    );
    if (res['success']) {
      setState(() {
        _tasks = res['tasks'];
        _totalPages = res['totalPages'];
        _totalElements = res['totalElements'];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
      }
    }
  }

  Future<void> _acceptTask(int id) async {
    setState(() => _isLoading = true);
    final res = await _taskService.updateTaskStatus(id, 'IN_PROGRESS');
    if (res['success']) {
      _fetchTasks();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
      }
    }
  }

''' + content.substring(fetchTasksEnd);
  }

  // 6. Remove fetchTrainers method
  final fetchTrainersEnd = content.indexOf('  Color _getStatusBgColor(String status) {');
  if (fetchTrainersEnd != -1) {
    final ftStart = content.indexOf('  Future<void> _fetchTrainers() async {');
    content = content.substring(0, ftStart) + content.substring(fetchTrainersEnd);
  }

  // 7. Remove Add Task button
  content = content.replaceFirst('''            ElevatedButton.icon(
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
            ),''', '');

  // 8. Fix table header Action
  content = content.replaceFirst("SizedBox(width: 50, child: Text('ACTION', style: _headerStyle)),", "SizedBox(width: 80, child: Text('ACTION', style: _headerStyle)),");

  // 9. Fix list action column
  content = content.replaceFirst(r'''                          SizedBox(
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
                          ),''', r'''                          SizedBox(
                            width: 80, 
                            child: Row(
                              children: [
                                if (task.assignees.isNotEmpty && task.assignees.first.status == 'ASSIGNED') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF28B79B)),
                                    onPressed: () => _acceptTask(task.id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Accept Task',
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF6B7280)),
                                  onPressed: () {
                                    setState(() {
                                      _editingTask = task;
                                      _selectedTabIndex = 0;
                                      _activities = [];
                                      _editDescriptionController.text = task.description;
                                      _editStatus = task.assignees.isNotEmpty ? task.assignees.first.status : 'ASSIGNED';
                                    });
                                    _fetchTaskActivities(task.id);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'View Details',
                                ),
                              ],
                            )
                          ),''');
                          
  // 10. Write it back
  file.writeAsStringSync(content);
}
