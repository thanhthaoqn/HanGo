import 'package:flutter/material.dart';

import '../../../data/repositories/exam_repository.dart';
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
  // Emerald palette
  static const _emerald = Color(0xFF28B79B);
  static const _emeraldDark = Color(0xFF0B6660);
  static const _emeraldLight = Color(0xFFE6F7F4);
  static const _emeraldBorder = Color(0xFFB2DFDB);
  static const _textDark = Color(0xFF0F3D3E);

  // Target score options
  static const List<double> _scoreOptions = [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0];

  // Timeframe options (weeks)
  static const List<Map<String, dynamic>> _timeOptions = [
    {'weeks': 4, 'label': '1 Month'},
    {'weeks': 8, 'label': '2 Months'},
    {'weeks': 12, 'label': '3 Months'},
    {'weeks': 16, 'label': '4 Months'},
    {'weeks': 24, 'label': '6 Months'},
    {'weeks': 48, 'label': '1 Year'},
  ];

  bool _isLoadingAverage = true;
  double _averageScore = 0.0;
  String _aiFeedback = "";
  String? _errorMessage;
  bool _isCreating = false;

  double? _selectedScore;
  int? _selectedWeeks;

  @override
  void initState() {
    super.initState();
    _fetchAverageScore();
  }

  Future<void> _fetchAverageScore() async {
    try {
      final repository = ExamRepository();
      final allAttempts = await repository.fetchMyExamAttempts();

      if (allAttempts.isEmpty) {
        setState(() {
          _averageScore = 0.0;
          _aiFeedback = "No exam history found. Take an exam first to get personalized insights.";
          _isLoadingAverage = false;
        });
        return;
      }

      // Calculate true average score
      double totalScore = 0.0;
      int scoredCount = 0;

      for (final attempt in allAttempts) {
        final score = attempt['score'];
        if (score != null) {
          totalScore += (score is num) ? score.toDouble() : double.tryParse(score.toString()) ?? 0.0;
          scoredCount++;
        }
      }

      _averageScore = scoredCount > 0 ? totalScore / scoredCount : 0.0;

      // Round to 1 decimal
      _averageScore = double.parse(_averageScore.toStringAsFixed(1));

      // Build AI feedback using real data
      final weakSkill = widget.weakestSkill.isNotEmpty ? widget.weakestSkill : "General";
      _aiFeedback =
          "Based on ${allAttempts.length} exam attempt${allAttempts.length > 1 ? 's' : ''}, "
          "your average score is ${_averageScore.toStringAsFixed(1)}/10. "
          "Your weakest area is $weakSkill — focusing here will boost your score the fastest.";

      setState(() {
        _isLoadingAverage = false;
      });
    } catch (e) {
      debugPrint("Error fetching average score: $e");
      setState(() {
        _averageScore = 0.0;
        _isLoadingAverage = false;
        _aiFeedback = "Could not load exam history. Please try again later.";
      });
    }
  }

  bool _isFeasible(double target, int weeks) {
    return (target - _averageScore) <= (weeks * 0.5);
  }

  void _onScoreSelected(double score) {
    setState(() {
      _selectedScore = score;
      _errorMessage = null;
      _validateSelection();
    });
  }

  void _onTimeSelected(int weeks) {
    setState(() {
      _selectedWeeks = weeks;
      _errorMessage = null;
      _validateSelection();
    });
  }

  void _validateSelection() {
    if (_selectedScore != null && _selectedWeeks != null) {
      if (!_isFeasible(_selectedScore!, _selectedWeeks!)) {
        double maxGain = _selectedWeeks! * 0.5;
        double maxReachable = _averageScore + maxGain;
        _errorMessage =
            "Not feasible! In $_selectedWeeks weeks you can reach up to "
            "${maxReachable.toStringAsFixed(1)}. Choose a longer timeframe or lower target.";
      }
    }
  }

  bool get _canCreate =>
      _selectedScore != null &&
      _selectedWeeks != null &&
      _errorMessage == null &&
      !_isCreating;

  void _createPathway() async {
    if (!_canCreate) return;

    // Show overwrite confirmation
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: _emeraldLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync, color: _emerald, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Overwrite Pathway?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AI will create a new learning pathway based on your target. Your old pathway will be replaced.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Yes, Create',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final pathwayRepo = PathwayRepository();
      
      final goalName = "Target Score: $_selectedScore";
      final targetDate = DateTime.now().add(Duration(days: _selectedWeeks! * 7)).toIso8601String().substring(0, 10);
      
      await pathwayRepo.generatePathway(
        examAttemptId: widget.examAttemptId,
        goalName: goalName,
        targetDate: targetDate,
        hoursPerWeek: 5, // Defaulting to 5 as there is no UI for hours per week in this dialog
      );

      if (!mounted) return;
      Navigator.pop(context);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 420,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _emeraldLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flag_rounded, color: _emerald, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Set Your Goal",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.grey.shade500, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Loading
                if (_isLoadingAverage)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: CircularProgressIndicator(color: _emerald),
                    ),
                  )
                else ...[
                  // AI Insight Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE6F7F4), Color(0xFFD5F5F0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _emeraldBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome, color: _emerald, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _aiFeedback,
                            style: const TextStyle(
                              color: _emeraldDark,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Target Score Section
                  const Text(
                    "Target Score",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _scoreOptions.map((score) {
                      final isSelected = _selectedScore == score;
                      final isBelowAvg = score <= _averageScore;
                      return GestureDetector(
                        onTap: isBelowAvg ? null : () => _onScoreSelected(score),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isBelowAvg
                                ? Colors.grey.shade100
                                : isSelected
                                    ? _emerald
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isBelowAvg
                                  ? Colors.grey.shade200
                                  : isSelected
                                      ? _emerald
                                      : _emeraldBorder,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _emerald.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            score == score.toInt() ? '${score.toInt()}.0' : score.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isBelowAvg
                                  ? Colors.grey.shade400
                                  : isSelected
                                      ? Colors.white
                                      : _emeraldDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Timeframe Section
                  const Text(
                    "Timeframe",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeOptions.map((opt) {
                      final weeks = opt['weeks'] as int;
                      final label = opt['label'] as String;
                      final isSelected = _selectedWeeks == weeks;
                      // Show infeasibility hint
                      final infeasible = _selectedScore != null && !_isFeasible(_selectedScore!, weeks);
                      return GestureDetector(
                        onTap: () => _onTimeSelected(weeks),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _emerald
                                : infeasible
                                    ? const Color(0xFFFEF2F2)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? _emerald
                                  : infeasible
                                      ? const Color(0xFFFECACA)
                                      : _emeraldBorder,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _emerald.withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : infeasible
                                      ? const Color(0xFFEF4444)
                                      : _emeraldDark,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canCreate ? _createPathway : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _emerald,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
        ),
      ),
    );
  }
}
