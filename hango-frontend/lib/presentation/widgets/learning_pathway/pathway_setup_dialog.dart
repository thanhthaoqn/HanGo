import 'package:flutter/material.dart';

class PathwaySetupDialog extends StatefulWidget {
  final int? examAttemptId;
  final int? existingPathwayId;

  /// If `examAttemptId` is provided, the dialog will be used to generate a new pathway.
  /// If `existingPathwayId` is provided, it will be used to schedule an existing pathway.
  const PathwaySetupDialog({
    Key? key,
    this.examAttemptId,
    this.existingPathwayId,
  }) : super(key: key);

  @override
  State<PathwaySetupDialog> createState() => _PathwaySetupDialogState();
}

class _PathwaySetupDialogState extends State<PathwaySetupDialog> {
  final _goalController = TextEditingController();
  final _hoursController = TextEditingController(text: '5');
  DateTime? _targetDate;

  bool _isLoading = false;

  @override
  void dispose() {
    _goalController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _submit() {
    final goal = _goalController.text.trim();
    final hours = int.tryParse(_hoursController.text.trim()) ?? 0;

    if (goal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal name')),
      );
      return;
    }
    if (_targetDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target date')),
      );
      return;
    }
    if (hours <= 0 || hours > 168) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid hours per week (1-168)')),
      );
      return;
    }

    Navigator.pop(context, {
      'goalName': goal,
      'targetDate': _targetDate!.toIso8601String().split('T').first,
      'hoursPerWeek': hours,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Color(0xFF28B79B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Set Pathway Goals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Goal Name
            const Text(
              'What is your main goal?',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalController,
              decoration: InputDecoration(
                hintText: 'e.g., Pass IELTS with 7.0',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Target Date
            const Text(
              'Target Completion Date',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _targetDate == null
                          ? 'Select a date'
                          : '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                      style: TextStyle(
                        color: _targetDate == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        fontSize: 15,
                      ),
                    ),
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Hours Per Week
            const Text(
              'Hours Per Week',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g., 5',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixText: 'hours',
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
