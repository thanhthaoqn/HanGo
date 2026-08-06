import 'package:flutter/material.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../../domain/entities/learning_pathway.dart';

class EditGoalDialog extends StatefulWidget {
  final LearningPathway pathway;
  final bool isDarkMode;
  final PathwayRepository repository;
  final Function(LearningPathway) onUpdated;

  const EditGoalDialog({
    super.key,
    required this.pathway,
    required this.isDarkMode,
    required this.repository,
    required this.onUpdated,
  });

  @override
  State<EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<EditGoalDialog> {
  late TextEditingController _goalNameController;
  late TextEditingController _hoursController;
  late TextEditingController _targetDateController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _goalNameController = TextEditingController(text: widget.pathway.goalName ?? '');
    _hoursController = TextEditingController(text: widget.pathway.hoursPerWeek?.toString() ?? '10');
    _targetDateController = TextEditingController(text: widget.pathway.targetDate ?? '');
  }

  @override
  void dispose() {
    _goalNameController.dispose();
    _hoursController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)), // 2 years
    );
    if (picked != null) {
      final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _targetDateController.text = dateStr;
      });
    }
  }

  Future<void> _submit() async {
    if (_goalNameController.text.trim().isEmpty || 
        _targetDateController.text.trim().isEmpty || 
        _hoursController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final hours = int.tryParse(_hoursController.text.trim()) ?? 10;

    setState(() => _isLoading = true);
    try {
      final updatedPathway = await widget.repository.schedulePathway(
        pathwayId: widget.pathway.pathwayId,
        goalName: _goalNameController.text.trim(),
        targetDate: _targetDateController.text.trim(),
        hoursPerWeek: hours,
      );
      widget.onUpdated(updatedPathway);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final titleColor = widget.isDarkMode ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A);
    final inputFill = widget.isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final border = widget.isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.edit_calendar_rounded, color: widget.isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Text(
            'Edit Goal',
            style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal Name', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _goalNameController,
              style: TextStyle(color: titleColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputFill,
                hintText: 'E.g., Target 8.0 IELTS',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Target Date', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _targetDateController,
              readOnly: true,
              onTap: _selectDate,
              style: TextStyle(color: titleColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputFill,
                hintText: 'YYYY-MM-DD',
                suffixIcon: Icon(Icons.calendar_today_rounded, color: widget.isDarkMode ? const Color(0xFF8B949E) : Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Hours per week', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: titleColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputFill,
                hintText: 'E.g., 10',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28B79B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}
