import 'package:flutter/material.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../data/repositories/exam_repository.dart';

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
  // Theme palette based on dark/light mode
  late Color _primaryColor;
  late Color _primaryLight;
  late Color _primaryDark;
  late Color _borderColor;
  late Color _textColor;
  late Color _bgColor;

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
    _initColors();
    _preselectCurrentGoal();
    _fetchAverageScore();
  }

  void _initColors() {
    if (widget.isDarkMode) {
      _primaryColor = const Color(0xFF6366F1);
      _primaryDark = const Color(0xFF4F46E5);
      _primaryLight = const Color(0xFF1E293B);
      _borderColor = const Color(0xFF334155);
      _textColor = const Color(0xFFF1F5F9);
      _bgColor = const Color(0xFF0F172A);
    } else {
      _primaryColor = const Color(0xFF28B79B);
      _primaryDark = const Color(0xFF0B6660);
      _primaryLight = const Color(0xFFE6F7F4);
      _borderColor = const Color(0xFFB2DFDB);
      _textColor = const Color(0xFF0F3D3E);
      _bgColor = Colors.white;
    }
  }

  void _preselectCurrentGoal() {
    // Try to parse existing score
    if (widget.pathway.goalName != null && widget.pathway.goalName!.startsWith("Target Score: ")) {
      double? score = double.tryParse(widget.pathway.goalName!.replaceAll("Target Score: ", ""));
      if (score != null && _scoreOptions.contains(score)) {
        _selectedScore = score;
      }
    }
    
    // Try to parse timeframe
    if (widget.pathway.targetDate != null) {
      DateTime targetDate = DateTime.tryParse(widget.pathway.targetDate!) ?? DateTime.now();
      int daysDifference = targetDate.difference(DateTime.now()).inDays;
      int weeks = (daysDifference / 7).round();
      
      // Find closest week option
      int closestWeeks = 4;
      int minDiff = 999;
      for (var opt in _timeOptions) {
        int optWeeks = opt['weeks'] as int;
        int diff = (optWeeks - weeks).abs();
        if (diff < minDiff) {
          minDiff = diff;
          closestWeeks = optWeeks;
        }
      }
      _selectedWeeks = closestWeeks;
    }
  }

  Future<void> _fetchAverageScore() async {
    try {
      final repository = ExamRepository();
      final allAttempts = await repository.fetchMyExamAttempts();

      if (allAttempts.isEmpty) {
        setState(() {
          _averageScore = 0.0;
          _aiFeedback = widget.isDarkMode
              ? "No exam history found. Your schedule will be updated without baseline evaluation."
              : "No exam history found. Your schedule will be updated without baseline evaluation.";
          _isLoadingAverage = false;
        });
        return;
      }

      double recentScore = 0.0;
      double historicalSum = 0.0;
      int historicalCount = 0;
      bool hasRecent = false;

      for (int i = 0; i < allAttempts.length; i++) {
        final attempt = allAttempts[i];
        final scoreRaw = attempt['score'];
        if (scoreRaw != null) {
          double scoreVal = (scoreRaw is num) ? scoreRaw.toDouble() : double.tryParse(scoreRaw.toString()) ?? 0.0;
          
          if (!hasRecent) {
            recentScore = scoreVal;
            hasRecent = true;
          } else {
            historicalSum += scoreVal;
            historicalCount++;
          }
        }
      }

      if (hasRecent) {
        if (historicalCount > 0) {
          double historicalAverage = historicalSum / historicalCount;
          _averageScore = (recentScore * 0.5) + (historicalAverage * 0.5);
        } else {
          _averageScore = recentScore;
        }
      } else {
        _averageScore = 0.0;
      }

      _averageScore = double.parse(_averageScore.toStringAsFixed(1));

      final weakSkill = widget.pathway.weakSkills.isNotEmpty ? widget.pathway.weakSkills.first : "General";
      _aiFeedback =
          "Based on your overall history, your baseline score is ${_averageScore.toStringAsFixed(1)}/10. "
          "Adjust your target score and timeframe to let the AI Mentor reorganize your schedule for $weakSkill.";

      setState(() {
        _isLoadingAverage = false;
      });
    } catch (e) {
      debugPrint("Error fetching average score: $e");
      setState(() {
        _averageScore = 0.0;
        _isLoadingAverage = false;
        _aiFeedback = "Could not load exam history to evaluate your baseline.";
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

  bool get _canSubmit =>
      _selectedScore != null &&
      _selectedWeeks != null &&
      _errorMessage == null &&
      !_isCreating;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _isCreating = true);
    try {
      final goalName = "Target Score: $_selectedScore";
      final targetDate = DateTime.now().add(Duration(days: _selectedWeeks! * 7)).toIso8601String().substring(0, 10);
      
      final updatedPathway = await widget.repository.schedulePathway(
        pathwayId: widget.pathway.pathwayId,
        goalName: goalName,
        targetDate: targetDate,
        hoursPerWeek: widget.pathway.hoursPerWeek ?? 10,
      );
      widget.onUpdated(updatedPathway);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorMessage = "Failed to update schedule: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _bgColor,
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
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.edit_calendar_rounded, color: _primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Edit Your Goal",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: widget.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Loading
                if (_isLoadingAverage)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: CircularProgressIndicator(color: _primaryColor),
                    ),
                  )
                else ...[
                  // AI Insight Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.isDarkMode 
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFFE6F7F4), const Color(0xFFD5F5F0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, color: _primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _aiFeedback,
                            style: TextStyle(
                              color: widget.isDarkMode ? const Color(0xFF94A3B8) : _primaryDark,
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
                  Text(
                    "Target Score",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
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
                                ? (widget.isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade100)
                                : isSelected
                                    ? _primaryColor
                                    : (widget.isDarkMode ? _bgColor : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isBelowAvg
                                  ? (widget.isDarkMode ? const Color(0xFF334155) : Colors.grey.shade200)
                                  : isSelected
                                      ? _primaryColor
                                      : _borderColor,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _primaryColor.withOpacity(0.25),
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
                                  ? (widget.isDarkMode ? const Color(0xFF475569) : Colors.grey.shade400)
                                  : isSelected
                                      ? Colors.white
                                      : (widget.isDarkMode ? const Color(0xFFE2E8F0) : _primaryDark),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Timeframe Section
                  Text(
                    "Timeframe",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
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
                      final infeasible = _selectedScore != null && !_isFeasible(_selectedScore!, weeks);
                      
                      return GestureDetector(
                        onTap: () => _onTimeSelected(weeks),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _primaryColor
                                : infeasible
                                    ? (widget.isDarkMode ? const Color(0xFF450a0a) : const Color(0xFFFEF2F2))
                                    : (widget.isDarkMode ? _bgColor : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? _primaryColor
                                  : infeasible
                                      ? (widget.isDarkMode ? const Color(0xFF7f1d1d) : const Color(0xFFFECACA))
                                      : _borderColor,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _primaryColor.withOpacity(0.25),
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
                                      : (widget.isDarkMode ? const Color(0xFFE2E8F0) : _primaryDark),
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
                        color: widget.isDarkMode ? const Color(0xFF450a0a) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: widget.isDarkMode ? const Color(0xFF7f1d1d) : const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: widget.isDarkMode ? const Color(0xFFfca5a5) : const Color(0xFFB91C1C),
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
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade200,
                        disabledForegroundColor: widget.isDarkMode ? const Color(0xFF475569) : Colors.grey.shade400,
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
                              "Update Schedule",
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
