import sys

file_path = 'lib/presentation/pages/trainer_lead/trainer_lead_task_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# find index of line 539 (which is 0-indexed 538 in original, but let's find the exact string)
start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.strip() == "const SizedBox(height: 24)," and "Row(" in lines[i+2] and start_idx == -1:
        if i > 500 and i < 600:
            start_idx = i
    if line.strip() == "OutlinedButton(" and "onPressed: () => setState(() => _editingTask = null)," in lines[i+1]:
        if i > 800 and i < 860:
            end_idx = i - 2 # The Row( mainAxisAlignment.end line
            break

if start_idx == -1 or end_idx == -1:
    print(f"Could not find indices: {start_idx}, {end_idx}")
    sys.exit(1)

print(f"Replacing lines {start_idx} to {end_idx}")

new_ui = """                    const SizedBox(height: 24),
                    
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
                      mainAxisAlignment: MainAxisAlignment.end,
"""

del lines[start_idx:end_idx+1]
lines.insert(start_idx, new_ui)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)
print("Updated successfully")
