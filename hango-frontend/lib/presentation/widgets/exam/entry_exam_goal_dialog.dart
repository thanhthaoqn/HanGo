import 'package:flutter/material.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../pages/learner/learning_pathway_page.dart';

class EntryExamGoalDialog extends StatefulWidget {
  final double currentScore;
  final int attemptId;

  const EntryExamGoalDialog({
    super.key,
    required this.currentScore,
    required this.attemptId,
  });

  @override
  State<EntryExamGoalDialog> createState() => _EntryExamGoalDialogState();
}

class _EntryExamGoalDialogState extends State<EntryExamGoalDialog> {
  double _targetScore = 7.0;
  int _targetWeeks = 4;
  bool _isLoading = false;

  final List<double> _scoreOptions = [5.0, 6.0, 7.0, 8.0, 9.0, 9.5];
  final List<int> _weekOptions = [2, 4, 8, 12, 24];

  String _getWeeksLabel(int weeks) {
    if (weeks == 2) return '2 weeks';
    if (weeks == 4) return '1 month';
    if (weeks == 8) return '2 months';
    if (weeks == 12) return '3 months';
    if (weeks == 24) return '6 months';
    return '$weeks weeks';
  }

  bool _isFeasible() {
    double gap = _targetScore - widget.currentScore;
    if (gap <= 0) return true;
    return gap <= (_targetWeeks * 0.5);
  }

  Future<void> _handleCreatePathway() async {
    setState(() => _isLoading = true);

    try {
      final pathwayRepository = PathwayRepository();
      await pathwayRepository.generatePathway(
        examAttemptId: widget.attemptId,
        goalName: 'Target ${_targetScore}',
        targetDate: DateTime.now().add(Duration(days: _targetWeeks * 7)).toIso8601String().split('T').first,
        hoursPerWeek: 5, // Default 5 hours/week for now
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LearningPathwayPage(),
        ),
      );
    } catch (e) {
      debugPrint("Error generating pathway: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feasible = _isFeasible();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF10B981),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Exam completed!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your score: ${widget.currentScore.toStringAsFixed(1)} / 10.0',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Set your target score and time frame to generate a personalized learning pathway.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            
            // Goal Selection Form
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Score',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _targetScore,
                            isExpanded: true,
                            items: _scoreOptions.map((score) {
                              return DropdownMenuItem(
                                value: score,
                                child: Text('$score+'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _targetScore = val);
                            },
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
                      const Text(
                        'Time Frame',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _targetWeeks,
                            isExpanded: true,
                            items: _weekOptions.map((weeks) {
                              return DropdownMenuItem(
                                value: weeks,
                                child: Text(_getWeeksLabel(weeks)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _targetWeeks = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Feasibility Warning
            if (!feasible)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This goal is unrealistic based on your current score (${widget.currentScore.toStringAsFixed(1)}). Please allow more time or lower your target to create an effective pathway.',
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 52), // placeholder to prevent layout shift

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (feasible && !_isLoading) ? _handleCreatePathway : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('Create a pathway for beginners', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
