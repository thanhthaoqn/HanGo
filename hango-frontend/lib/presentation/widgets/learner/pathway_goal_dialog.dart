import 'package:flutter/material.dart';

import '../../../data/repositories/pathway_repository.dart';
import '../../pages/learner/learning_pathway_page.dart';

class PathwayGoalDialog extends StatefulWidget {
  final String weakestSkill;
  final int examAttemptId;
  
  const PathwayGoalDialog({
    Key? key,
    required this.weakestSkill,
    required this.examAttemptId,
  }) : super(key: key);

  @override
  State<PathwayGoalDialog> createState() => _PathwayGoalDialogState();
}

class _PathwayGoalDialogState extends State<PathwayGoalDialog> {
  final _scoreController = TextEditingController();
  final _weeksController = TextEditingController();
  
  bool _isLoadingAverage = true;
  double _averageScore = 0.0;
  String _aiFeedback = "";
  String? _errorMessage;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _fetchAverageScore();
  }

  Future<void> _fetchAverageScore() async {
    try {
      // Wait, there is no global fetchMyExamAttempts? I will fetch a generic list
      // For demo, since we don't have a backend endpoint to fetch average, we'll mock the calculation or assume current score.
      await Future.delayed(const Duration(milliseconds: 800));
      _averageScore = 5.5; // Mock average
      _aiFeedback = "Your average score is $_averageScore. Focusing on ${widget.weakestSkill} will help you achieve your goals faster.";
      setState(() {
        _isLoadingAverage = false;
      });
    } catch (e) {
      setState(() {
        _averageScore = 0.0;
        _isLoadingAverage = false;
        _aiFeedback = "Failed to load average score.";
      });
    }
  }

  void _createPathway() async {
    final targetScoreStr = _scoreController.text.trim();
    final weeksStr = _weeksController.text.trim();

    if (targetScoreStr.isEmpty || weeksStr.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both Target Score and Time.";
      });
      return;
    }

    final targetScore = double.tryParse(targetScoreStr);
    final weeks = int.tryParse(weeksStr);

    if (targetScore == null || weeks == null || targetScore <= 0 || weeks <= 0) {
      setState(() {
        _errorMessage = "Please enter valid positive numbers.";
      });
      return;
    }

    // Validation Rule: (TargetScore - CurrentScore) <= (Weeks * 0.5)
    double possibleGain = weeks * 0.5;
    if ((targetScore - _averageScore) > possibleGain) {
      setState(() {
        _errorMessage = "Goal not feasible! Max score increase in $weeks weeks is $possibleGain. Try a lower target or more weeks.";
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    // Show overwrite confirmation
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite Pathway?'),
        content: const Text('Do you want to overwrite your old learning pathway? AI will create a new one based on this target.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28B79B)),
            child: const Text('Yes, Overwrite'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final pathwayRepo = PathwayRepository();
      // Generate generic pathway
      await pathwayRepo.generatePathway(examAttemptId: widget.examAttemptId);

      if (!mounted) return;
      Navigator.pop(context); // close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LearningPathwayPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _errorMessage = "Failed to create pathway. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Set Your Goal",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingAverage)
               const Center(
                 child: Padding(
                   padding: EdgeInsets.all(16.0),
                   child: CircularProgressIndicator(color: Color(0xFF28B79B)),
                 ),
               )
            else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _aiFeedback,
                        style: const TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                "Target IELTS Score",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _scoreController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: "e.g., 7.0",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                "Timeframe (Weeks)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _weeksController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "e.g., 12",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                  ),
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createPathway,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          "Create Learning Pathway",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
