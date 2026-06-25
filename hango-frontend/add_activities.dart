import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  final lines = file.readAsLinesSync();
  final newLines = <String>[];
  
  bool addedImport = false;
  for (int i = 0; i < lines.length; i++) {
    if (!addedImport && lines[i].contains('import')) {
      newLines.add("import '../../../data/models/task_activity_model.dart';");
      addedImport = true;
    }
    
    if (lines[i].contains('DateTime? _editDeadline;')) {
      newLines.add('  List<TaskActivityModel> _activities = [];');
    }
    
    if (lines[i].contains('Future<void> _fetchTasks() async {')) {
      newLines.add(r'''
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
''');
    }
    
    newLines.add(lines[i]);
  }
  
  file.writeAsStringSync(newLines.join('\n'));
}
