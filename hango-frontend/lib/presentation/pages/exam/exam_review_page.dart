import 'package:flutter/material.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/shared_header.dart';

class ExamReviewPage extends StatefulWidget {
  final Exam exam;
  final Map<String, dynamic> attempt;

  const ExamReviewPage({
    Key? key,
    required this.exam,
    required this.attempt,
  }) : super(key: key);

  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

class _ExamReviewPageState extends State<ExamReviewPage> {
  List<Map<String, dynamic>> _examQuestions = [];
  late Map<int, int> _userAnswers;
  Map<int, bool> _correctnessMap = {};
  Map<int, int> _correctAnswersMap = {};
  bool _isLoadingQuestions = true;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _questionKeys = {};
  final ValueNotifier<double> _sidebarOffsetY = ValueNotifier<double>(0.0);


  @override
  void initState() {
    super.initState();
    
    // Parse answers Map from the attempt — safely handle null values
    final rawAnswers = widget.attempt['answers'];
    if (rawAnswers is Map) {
      _userAnswers = {};
      rawAnswers.forEach((key, value) {
        if (key != null && value != null) {
          final k = int.tryParse(key.toString());
          final v = int.tryParse(value.toString());
          if (k != null && v != null) {
            _userAnswers[k - 1] = v; // Convert 1-based key to 0-based
          }
        }
      });
    } else {
      _userAnswers = {};
    }

    // Parse correctness map from the attempt (Backend provides {questionIndex: true/false})
    final rawCorrectness = widget.attempt['correctness'];
    if (rawCorrectness is Map) {
      rawCorrectness.forEach((key, value) {
        if (key != null && value != null) {
          final k = int.tryParse(key.toString());
          if (k != null) {
            _correctnessMap[k - 1] = value == true;
          }
        }
      });
    }

    // Parse correct answers map from the attempt (Backend provides {questionIndex: correctOptionIndex})
    final rawCorrectAnswers = widget.attempt['correctAnswers'];
    if (rawCorrectAnswers is Map) {
      rawCorrectAnswers.forEach((key, value) {
        if (key != null && value != null) {
          final k = int.tryParse(key.toString());
          final v = int.tryParse(value.toString());
          if (k != null && v != null) {
            _correctAnswersMap[k - 1] = v;
          }
        }
      });
    }

    _fetchQuestions();
    _scrollController.addListener(_updateSidebarOffset);
  }

  Future<void> _fetchQuestions() async {
    try {
      final repository = ExamRepository();
      final questions = await repository.fetchExamQuestions(widget.exam.id);
      
      setState(() {
        _examQuestions = questions;
        for (int i = 0; i < _examQuestions.length; i++) {
          _questionKeys[i] = GlobalKey();
        }
        _isLoadingQuestions = false;
      });
    } catch (e) {
      debugPrint("Error fetching exam questions: $e");
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  /// Extract option text safely — API returns [{id, optionText}] or plain strings
  String _getOptionText(dynamic option) {
    if (option is Map) {
      return option['optionText']?.toString() ?? option['content']?.toString() ?? '';
    }
    return option?.toString() ?? '';
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateSidebarOffset);
    _scrollController.dispose();
    _sidebarOffsetY.dispose();
    super.dispose();
  }

  void _updateSidebarOffset() {
    double triggerOffset = 220.0;
    double topPadding = 20.0;
    
    double newOffset = 0.0;
    if (_scrollController.offset > triggerOffset) {
      newOffset = _scrollController.offset - triggerOffset + topPadding;
      
      double estQuestionsHeight = _examQuestions.length * 600.0;
      double maxOffset = estQuestionsHeight - 250.0;
      if (maxOffset < 0) maxOffset = 0;
      if (newOffset > maxOffset) {
        newOffset = maxOffset;
      }
    }
    
    _sidebarOffsetY.value = newOffset;
  }

  void _scrollToQuestion(int index) {
    final key = _questionKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final double scoreValue = (widget.attempt['score'] as num?)?.toDouble() ?? 0.0;
    final isPassed = scoreValue >= 5.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Exams'),
      body: _isLoadingQuestions
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28B79B)),
            )
          : SingleChildScrollView(
              controller: _scrollController,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48.0 : 20.0,
                    vertical: 32,
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Back to Exam Details',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header Summary Panel
                    _buildSummaryHeader(scoreValue, isPassed),
                    const SizedBox(height: 32),

                    // Two columns layout
                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildQuestionsList()),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 1,
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _sidebarOffsetY,
                                  builder: (context, offsetY, child) {
                                    return Padding(
                                      padding: EdgeInsets.only(top: offsetY),
                                      child: child,
                                    );
                                  },
                                  child: _buildSideNavPanel(),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildSideNavPanel(),
                              const SizedBox(height: 32),
                              _buildQuestionsList(),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            ),
            SharedFooter(isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(double score, bool isPassed) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPassed
              ? [const Color(0xFF28B79B), const Color(0xFF167B66)]
              : [const Color(0xFFEF4444), const Color(0xFFB91C1C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPassed ? const Color(0xFF28B79B) : const Color(0xFFEF4444)).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          // Score Circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review: ${widget.exam.title}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Attempt: #${widget.attempt['attemptNumber'] ?? '?'}',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_month, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      widget.attempt['date'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_examQuestions.length, (index) {
        final q = _examQuestions[index];
        final options = q['options'] as List? ?? [];
        final userSelectedIndex = _userAnswers[index];
        // Use correctness map from the attempt data (Backend-verified)
        final isCorrect = _correctnessMap[index] ?? false;

        final group = q['group'] as Map<String, dynamic>?;
        final passage = group?['passage'] as String?;
        final isFirstQuestionInGroup = index == 0 || (group != null && _examQuestions[index - 1]['group']?['id'] != group['id']);
        final showPassage = passage != null && passage.isNotEmpty && isFirstQuestionInGroup;

        return Container(
          key: _questionKeys[index],
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Render Passage if exists and is first question of the group
              if (showPassage)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article_outlined, color: Color(0xFF64748B), size: 20),
                          const SizedBox(width: 8),
                          const Text('Reading Passage', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        passage,
                        style: const TextStyle(height: 1.6, color: Color(0xFF334155), fontSize: 14),
                      ),
                    ],
                  ),
                ),

              // Question Number Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'QUESTION ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCorrect ? 'Correct' : 'Incorrect',
                        style: TextStyle(
                          color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Skill tag
              if (q['skill'] != null && q['skill'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      q['skill'].toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B6660),
                      ),
                    ),
                  ),
                ),

              // Question Text
              Text(
                'Question ${index + 1}: ${q['content'] ?? ''}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Options
              Column(
                children: List.generate(options.length, (optIdx) {
                  final optionText = _getOptionText(options[optIdx]);
                  final isUserSelected = userSelectedIndex == optIdx;
                  final isCorrectAnswer = _correctAnswersMap[index] == optIdx;
                  
                  final isSelectedCorrectOption = isUserSelected && isCorrect;
                  final isSelectedWrongOption = isUserSelected && !isCorrect;

                  Color optionBg = Colors.white;
                  Color optionBorder = Colors.grey.shade200;
                  Widget? suffixIcon;

                  if (isSelectedCorrectOption || (isCorrectAnswer && !isCorrect)) {
                    // This is the correct option (either selected correctly, or highlighting the correct one if user missed)
                    optionBg = const Color(0xFFE8F8F5);
                    optionBorder = const Color(0xFF28B79B);
                    suffixIcon = const Icon(Icons.check_circle, color: Color(0xFF28B79B), size: 18);
                  } else if (isSelectedWrongOption) {
                    // This is the wrong option the user selected
                    optionBg = const Color(0xFFFEE2E2);
                    optionBorder = const Color(0xFFEF4444);
                    suffixIcon = const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 18);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: optionBg,
                      border: Border.all(color: optionBorder, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Radio circle
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelectedCorrectOption
                                  ? const Color(0xFF28B79B)
                                  : (isSelectedWrongOption ? const Color(0xFFEF4444) : Colors.grey.shade400),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: (isSelectedCorrectOption || isCorrectAnswer) || isUserSelected
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (isSelectedCorrectOption || isCorrectAnswer) ? const Color(0xFF28B79B) : const Color(0xFFEF4444),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        
                        // Option Label & Text
                        Text(
                          '${String.fromCharCode(65 + optIdx)}. ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (isSelectedCorrectOption || isCorrectAnswer)
                                ? const Color(0xFF167B66)
                                : (isSelectedWrongOption ? const Color(0xFFEF4444) : const Color(0xFF4B5563)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(
                              color: (isSelectedCorrectOption || isCorrectAnswer)
                                  ? const Color(0xFF167B66)
                                  : (isSelectedWrongOption ? const Color(0xFFEF4444) : const Color(0xFF1F2937)),
                              fontWeight: isUserSelected || isCorrectAnswer ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (suffixIcon != null) suffixIcon,
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Explanation Panel
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Explanation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            q['explanation'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF78350F),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSideNavPanel() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Question Navigator',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _examQuestions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              // Use correctness map from the attempt data (Backend-verified)
              final isCorrect = _correctnessMap[index] ?? false;

              return InkWell(
                onTap: () => _scrollToQuestion(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: isCorrect ? const Color(0xFFE8F8F5) : const Color(0xFFFEE2E2),
                    border: Border.all(
                      color: isCorrect ? const Color(0xFF28B79B) : const Color(0xFFEF4444),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? const Color(0xFF167B66) : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFE8F8F5), border: Border.all(color: const Color(0xFF28B79B)), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              const Text('Correct', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFFEE2E2), border: Border.all(color: const Color(0xFFEF4444)), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              const Text('Incorrect', style: TextStyle(fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}
