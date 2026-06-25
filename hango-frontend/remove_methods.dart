import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  
  bool skip = false;
  int skipBrackets = 0;
  
  for (int i = 0; i < lines.length; i++) {
    // skip _fetchTrainers
    if (lines[i].contains('Future<void> _fetchTrainers() async {')) {
      skip = true;
      skipBrackets = 0;
    }
    // skip _buildAssignTaskView
    if (lines[i].contains('Widget _buildAssignTaskView() {')) {
      skip = true;
      skipBrackets = 0;
    }
    
    if (skip) {
      if (lines[i].contains('{')) skipBrackets += '{'.allMatches(lines[i]).length;
      if (lines[i].contains('}')) skipBrackets -= '}'.allMatches(lines[i]).length;
      if (skipBrackets == 0 && lines[i].contains('}')) {
        skip = false;
      }
      continue;
    }
    
    // Replace build method
    if (lines[i].contains('if (_isAssigningTask) {')) {
      newLines.removeLast(); // removes   Widget build(BuildContext context) {
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
