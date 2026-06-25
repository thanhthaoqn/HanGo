import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  
  bool skip = false;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('Widget _buildAssignTaskView() {')) {
      skip = true;
    }
    if (skip && lines[i].contains('Future<void> _fetchTaskActivities(int taskId) async {')) {
      skip = false;
    }
    
    if (lines[i].contains('if (_isAssigningTask) {')) {
      newLines.removeLast(); // removes Widget build
      newLines.add('  Widget build(BuildContext context) {');
      newLines.add('    if (_editingTask != null) {');
      newLines.add('      return _buildTaskDetailView();');
      newLines.add('    }');
      newLines.add('    return _buildTaskListView();');
      newLines.add('  }');
      i += 6; // skip the old build method body
      continue;
    }
    
    if (!skip) {
      newLines.add(lines[i]);
    }
  }
  
  file.writeAsStringSync(newLines.join('\n'));
}
