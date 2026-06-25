import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  
  bool skip = false;
  int skipBrackets = 0;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('ElevatedButton.icon(') && lines[i+1].contains('onPressed: () {') && lines[i+3].contains('_titleController.clear();')) {
      skip = true;
      skipBrackets = 0;
    }
    
    if (skip) {
      if (lines[i].contains('{')) skipBrackets += '{'.allMatches(lines[i]).length;
      if (lines[i].contains('}')) skipBrackets -= '}'.allMatches(lines[i]).length;
      if (skipBrackets == 0 && lines[i].contains(')')) {
        skip = false;
      }
      continue;
    }
    
    // Fix Action column
    if (lines[i].contains('width: 50,') && lines[i+1].contains('child: Row(') && lines[i+3].contains('IconButton(')) {
      newLines.add(r'''
                          SizedBox(
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
      i += 24; // skip old column
      continue;
    }
    
    newLines.add(lines[i]);
  }
  
  file.writeAsStringSync(newLines.join('\n'));
}
