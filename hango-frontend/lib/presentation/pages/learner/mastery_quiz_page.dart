import 'package:flutter/material.dart';

import '../../../data/repositories/pathway_repository.dart';
import '../../../domain/entities/learning_pathway.dart';

/// Man hinh Mastery Quiz that (spec 20 - B4): lay de tu backend, nop bai de
/// server cham diem. Thay cho mock score 90/100 truoc day.
class MasteryQuizPage extends StatefulWidget {
  final int pathwayId;
  final PathwayNode node;
  final bool isDarkMode;
  final ValueChanged<LearningPathway>? onCompleted;

  const MasteryQuizPage({
    super.key,
    required this.pathwayId,
    required this.node,
    this.isDarkMode = false,
    this.onCompleted,
  });

  @override
  State<MasteryQuizPage> createState() => _MasteryQuizPageState();
}

class _MasteryQuizPageState extends State<MasteryQuizPage> {
  final PathwayRepository _repository = PathwayRepository();

  List<Map<String, dynamic>> _questions = [];
  final Map<int, Set<int>> _answers = {}; // questionId -> selectedOptionIndices
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  int? _score;
  
  List<dynamic> _evaluations = [];
  bool _isReviewMode = false;

  bool get _dark => widget.isDarkMode;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final questions = await _repository.fetchMasteryQuestions(
        pathwayId: widget.pathwayId,
        nodeId: widget.node.id,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || _answers.length < _questions.length) return;
    setState(() => _isSubmitting = true);
    try {
      final response = await _repository.submitMasteryAnswers(
        pathwayId: widget.pathwayId,
        nodeId: widget.node.id,
        answers: _answers.map((k, v) => MapEntry(k, v.toList())),
      );
      if (!mounted) return;
      
      final updatedPathway = response['pathway'] as LearningPathway;
      final evaluations = response['evaluations'] as List<dynamic>? ?? [];
      
      // Diem so moi nhat cua node sau khi nop bai
      setState(() {
        _score = updatedPathway.nodes
            .firstWhere((n) => n.id == widget.node.id,
                orElse: () => widget.node)
            .masteryScore;
        _evaluations = evaluations;
        _isSubmitting = false;
      });
      widget.onCompleted?.call(updatedPathway);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Submit failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _dark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final cardColor = _dark ? const Color(0xFF161B22) : Colors.white;
    final textMain = _dark ? const Color(0xFFF0F6FC) : const Color(0xFF1E293B);
    final textSub = _dark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textMain,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _score != null ? 'Mastery Result' : 'Mastery Quiz',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
            ),
            Text(
              widget.node.courseTitle,
              style: TextStyle(fontSize: 12, color: textSub),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)))
          : _error != null && _questions.isEmpty
              ? _buildErrorBody(textMain, textSub, cardColor)
              : (_score != null && !_isReviewMode)
                  ? _buildResultBody(textMain, textSub, cardColor)
                  : _buildQuizBody(textMain, textSub, cardColor),
    );
  }

  Widget _buildErrorBody(Color textMain, Color textSub, Color cardColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              'Failed to load mastery questions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textMain),
            ),
            const SizedBox(height: 6),
            Text(_error ?? '', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textSub)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadQuestions,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF28B79B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizBody(Color textMain, Color textSub, Color cardColor) {
    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This course does not have mastery questions yet. Please contact your Trainer to add a quiz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: textSub),
          ),
        ),
      );
    }

    final allAnswered = _answers.length >= _questions.length;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final q = _questions[index];
              final qId = (q['questionId'] as num).toInt();
              final options = (q['options'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
              final passage = q['passage'] as String?;
              final selected = _answers[qId];

              Map<String, dynamic>? evaluation;
              List<int> correctOptions = [];
              String? explanation;
              if (_isReviewMode) {
                evaluation = _evaluations.cast<Map<String, dynamic>>().firstWhere(
                  (e) => e['questionId'] == qId,
                  orElse: () => <String, dynamic>{},
                );
                if (evaluation.isNotEmpty) {
                  correctOptions = (evaluation['correctOptions'] as List?)?.cast<int>() ?? [];
                  explanation = evaluation['explanation'] as String?;
                }
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6F7F4),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${index + 1}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF28B79B))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q['questionText']?.toString() ?? '',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: textMain,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    if (passage != null && passage.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _dark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(passage,
                            style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: textSub, height: 1.4)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ...List.generate(options.length, (i) {
                      final isMultipleChoice = q['isMultipleChoice'] == true;
                      final isSelected = selected?.contains(i) ?? false;
                      
                      Color bgColor = isSelected ? const Color(0xFFE6F7F4) : (_dark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC));
                      Color borderColor = isSelected ? const Color(0xFF28B79B) : Colors.transparent;
                      Color iconColor = isSelected ? const Color(0xFF28B79B) : textSub;
                      IconData iconData = isMultipleChoice 
                          ? (isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                          : (isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded);

                      if (_isReviewMode) {
                        final isCorrectOption = correctOptions.contains(i);
                        if (isCorrectOption) {
                          bgColor = const Color(0xFFECFDF5); // very light green
                          borderColor = const Color(0xFF10B981);
                          iconColor = const Color(0xFF10B981);
                          iconData = Icons.check_circle_rounded;
                        } else if (isSelected) {
                          // user selected it, but it's wrong
                          bgColor = const Color(0xFFFEF2F2); // very light red
                          borderColor = const Color(0xFFEF4444);
                          iconColor = const Color(0xFFEF4444);
                          iconData = Icons.cancel_rounded;
                        }
                      }

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isReviewMode ? null : () => setState(() {
                          if (isMultipleChoice) {
                            _answers.putIfAbsent(qId, () => {});
                            if (isSelected) {
                              _answers[qId]!.remove(i);
                            } else {
                              _answers[qId]!.add(i);
                            }
                          } else {
                            _answers[qId] = {i};
                          }
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: borderColor,
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                iconData,
                                size: 18,
                                color: iconColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + i)}. ${options[i]}',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      color: isSelected ? textMain : textSub,
                                      height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (_isReviewMode && explanation != null && explanation.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lời giải / Explanation:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                            const SizedBox(height: 4),
                            Text(explanation, style: const TextStyle(fontSize: 13, color: Color(0xFF0C4A6E), height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: _isReviewMode
                  ? FilledButton(
                      onPressed: () => setState(() => _isReviewMode = false),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Close Review'),
                    )
                  : FilledButton.icon(
                      onPressed: allAnswered && !_isSubmitting ? _submit : null,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(allAnswered
                          ? 'Submit (${_answers.length}/${_questions.length} questions)'
                          : 'Answered ${_answers.length}/${_questions.length} questions'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        disabledBackgroundColor:
                            (_dark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultBody(Color textMain, Color textSub, Color cardColor) {
    final score = _score ?? 0;
    final passed = score >= 80; // Phai khop voi MASTERY_PASS_SCORE phia backend
    final node = widget.node;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: passed ? const Color(0xFFE6F7F4) : const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Text('$score',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
              ),
              const SizedBox(height: 16),
              Text(
                passed ? 'Mastered! 🎉' : 'Not Mastered',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textMain),
              ),
              const SizedBox(height: 8),
              Text(
                passed
                    ? 'Excellent! Course "${node.courseTitle}" is now marked as mastered and will be scheduled for spaced repetition.'
                    : 'You need at least 80 points to master "${node.courseTitle}". Keep learning and try again later!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: textSub, height: 1.5),
              ),
              const SizedBox(height: 24),
              if (_evaluations.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isReviewMode = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF28B79B),
                      side: const BorderSide(color: Color(0xFF28B79B)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Review Answers'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back to Pathway'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
