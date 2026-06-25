import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer/trainer_task_page.dart');
  var content = file.readAsStringSync();
  
  // Fix imports
  content = content.replaceFirst("import '../../../data/models/task_activity_model.dart';\n", "");
  content = content.replaceFirst("import '../../../utils/image_picker.dart';\n", "");
  
  // Fix unused fields
  content = content.replaceAll("int _totalElements = 0;", "");
  content = content.replaceAll("_totalElements = res['totalElements'];", "");
  content = content.replaceAll("DateTime? _editDeadline;", "");
  content = content.replaceAll("String? _editReviewerId;", "");
  
  // Fix duplicate _activities
  content = content.replaceFirst("  List<TaskActivityModel> _activities = [];\n", "");
  
  // Fix _acceptTask parameter
  content = content.replaceAll("Future<void> _acceptTask(String id) async {", "Future<void> _acceptTask(int id) async {");
  
  // Remove unused methods
  // Remove _getStatusBgColor
  final colorStart = content.indexOf('Color _getStatusBgColor(String status) {');
  if (colorStart != -1) {
    final colorEnd = content.indexOf('}', colorStart) + 1;
    content = content.substring(0, colorStart) + content.substring(colorEnd);
  }
  
  // Remove _deleteTask
  final deleteStart = content.indexOf('Future<void> _deleteTask(int id) async {');
  if (deleteStart != -1) {
    final deleteEnd = content.indexOf('  }', deleteStart) + 3;
    content = content.substring(0, deleteStart) + content.substring(deleteEnd);
  }
  
  file.writeAsStringSync(content);
}
