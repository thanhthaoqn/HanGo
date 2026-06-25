import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  
  bool skip = false;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('Widget _buildTaskDetailView() {')) {
      skip = true;
      newLines.add(r'''
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
            const Text('Task Details', style: TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Task Details', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Outfit')),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        onTap: () => setState(() => _selectedTabIndex = 1),
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
                        decoration: BoxDecoration(color: const Color(0xFFE0E7FF).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC7D2FE))),
                        child: Text(task.title, style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937))),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                                const SizedBox(height: 8),
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF3F4F6)),
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(task.dueDate.toIso8601String().split('T').first, style: const TextStyle(fontSize: 13)),
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
                                const Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
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
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Reviewer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                                const SizedBox(height: 8),
                                Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF3F4F6)),
                                  alignment: Alignment.centerLeft,
                                  child: Text(assignee?.reviewerName ?? 'N/A', style: const TextStyle(fontSize: 13)),
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
                                        return DropdownMenuItem(value: status, child: Text(status.replaceAll('_', ' '), style: const TextStyle(fontSize: 13)));
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          task.description.isEmpty ? 'No description provided.' : task.description,
                          style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.5),
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
                                  if (_editStatus != null && _editStatus != assignee?.status) {
                                    final updateRes = await _taskService.updateTaskStatus(task.id, _editStatus!);
                                    if (updateRes['success'] == true) {
                                      setState(() => _editingTask = null);
                                      _fetchTasks();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task status updated successfully')));
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: ')));
                                      }
                                    }
                                  } else {
                                    setState(() => _editingTask = null);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28B79B),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Update Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                _buildActivityTab(task, assignee),
            ],
          ),
        ),
      ],
    );
  }
''');
    }
    
    if (skip && lines[i].contains('Widget _buildTaskListView() {')) {
      skip = false;
    }
    
    if (lines[i].contains("SizedBox(width: 50, child: Text('ACTION', style: _headerStyle))")) {
      newLines.add("                    SizedBox(width: 80, child: Text('ACTION', style: _headerStyle)),");
      continue;
    }
    
    if (lines[i].contains('Future<void> _fetchTasks() async {')) {
      newLines.add(r'''
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
''');
    }
    
    if (!skip) {
      newLines.add(lines[i]);
    }
  }
  
  file.writeAsStringSync(newLines.join('\n'));
}
