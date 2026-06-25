import 'dart:io';

void main() {
  final file = File('lib/presentation/pages/trainer_lead/trainer_lead_task_page.dart');
  final lines = file.readAsLinesSync();

  int startIdx = -1;
  int endIdx = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].trim() == 'const SizedBox(height: 24),' && i + 2 < lines.length && lines[i+2].contains('Row(') && startIdx == -1) {
      if (i > 500 && i < 600) {
        startIdx = i;
      }
    }
    if (lines[i].trim() == 'OutlinedButton(' && i + 1 < lines.length && lines[i+1].contains('onPressed: () => setState(() => _editingTask = null),')) {
      if (i > 800 && i < 860) {
        endIdx = i - 2; // Row( mainAxisAlignment.end line
        break;
      }
    }
  }

  if (startIdx == -1 || endIdx == -1) {
    print('Could not find indices: $startIdx, $endIdx');
    exit(1);
  }

  print('Replacing lines $startIdx to $endIdx');

  final newUi = '''                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Deadline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _editDeadline ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() => _editDeadline = date);
                                  }
                                },
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: Colors.white),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('dd/MM/yyyy').format(_editDeadline ?? DateTime.now()), style: const TextStyle(fontSize: 13)),
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9CA3AF)),
                                    ],
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
                              const Text('Assignee', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF3F4F6)),
                                alignment: Alignment.centerLeft,
                                child: Text(assignee?.creatorName ?? 'N/A', style: const TextStyle(fontSize: 13)),
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
                                      return DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 13)));
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
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(task.description.isEmpty ? 'No description' : task.description, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13)),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,''';

  lines.removeRange(startIdx, endIdx + 1);
  lines.insert(startIdx, newUi);

  file.writeAsStringSync(lines.join('\\n'));
  print('Updated successfully');
}
