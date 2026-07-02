import 'package:flutter/material.dart';
import '../../../domain/entities/exam.dart';
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
  late List<Map<String, dynamic>> _examQuestions;
  late Map<int, int> _userAnswers;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _questionKeys = {};
  final ValueNotifier<double> _sidebarOffsetY = ValueNotifier<double>(0.0);

  final List<Map<String, dynamic>> _baseQuestions = [
    {
      "content": "The book _______ you lent me yesterday is very interesting.",
      "options": ["who", "whom", "which", "whose"],
      "correctIndex": 2,
      "skill": "Grammar",
      "explanation": "'Which' is used as a relative pronoun to refer to things/objects (the book)."
    },
    {
      "content": "If I _______ you, I would study harder for the final exam.",
      "options": ["am", "was", "were", "would be"],
      "correctIndex": 2,
      "skill": "Grammar",
      "explanation": "In Type 2 conditional sentences, 'were' is used for all subjects in the 'if' clause."
    },
    {
      "content": "She has been working here _______ she graduated from university.",
      "options": ["for", "since", "in", "during"],
      "correctIndex": 1,
      "skill": "Vocabulary",
      "explanation": "'Since' is used to indicate a starting point in time for Present Perfect tense."
    },
    {
      "content": "The weather was _______ bad that we had to cancel the outdoor picnic.",
      "options": ["such", "so", "very", "too"],
      "correctIndex": 1,
      "skill": "Grammar",
      "explanation": "The structure is 'so + adjective + that + clause' (so bad that...)."
    },
    {
      "content": "By the time the police arrived, the bank robbers _______.",
      "options": ["escaped", "have escaped", "had escaped", "escape"],
      "correctIndex": 2,
      "skill": "Grammar",
      "explanation": "The past perfect 'had escaped' represents an action completed before another past action (arrived)."
    },
    {
      "content": "He is very keen _______ learning foreign languages.",
      "options": ["on", "in", "at", "for"],
      "correctIndex": 0,
      "skill": "Vocabulary",
      "explanation": "The adjective phrase is 'keen on' doing something (interested in)."
    },
    {
      "content": "The project was completed _______ schedule, which pleased the management.",
      "options": ["ahead of", "in front of", "prior to", "before"],
      "correctIndex": 0,
      "skill": "Vocabulary",
      "explanation": "'Ahead of schedule' is a standard idiom meaning faster or earlier than planned."
    },
    {
      "content": "Could you please _______ me a favor and carry this heavy suitcase?",
      "options": ["make", "do", "give", "take"],
      "correctIndex": 1,
      "skill": "Vocabulary",
      "explanation": "The standard collocation is 'do someone a favor'."
    },
    {
      "content": "Many species are in danger of extinction _______ habitat loss.",
      "options": ["because", "despite", "due to", "instead of"],
      "correctIndex": 2,
      "skill": "Reading Comprehension",
      "explanation": "'Due to' is a preposition meaning 'because of', followed by a noun phrase."
    },
    {
      "content": "The novel is widely considered a masterpiece, _______ it was written in only three weeks.",
      "options": ["although", "because", "since", "despite"],
      "correctIndex": 0,
      "skill": "Reading Comprehension",
      "explanation": "'Although' introduces a concession clause contradicting the first statement."
    }
  ];

  @override
  void initState() {
    super.initState();
    
    // Parse answers Map from the attempt
    final rawAnswers = widget.attempt['answers'];
    if (rawAnswers is Map) {
      _userAnswers = rawAnswers.map((key, value) => MapEntry(int.parse(key.toString()) - 1, int.parse(value.toString())));
    } else {
      _userAnswers = {};
    }

    // Generate same question set as take_exam_page.dart
    int targetCount = widget.exam.questionCount > 0 ? widget.exam.questionCount : 10;
    _examQuestions = [];
    for (int i = 0; i < targetCount; i++) {
      final base = _baseQuestions[i % _baseQuestions.length];
      _examQuestions.add({
        "id": i + 1,
        "content": base['content'],
        "options": base['options'],
        "correctIndex": base['correctIndex'],
        "skill": base['skill'],
        "explanation": base['explanation'],
      });
      _questionKeys[i] = GlobalKey();
    }

    _scrollController.addListener(_updateSidebarOffset);
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
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1440),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 20,
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
            SharedFooter(isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(double scoreValue, bool isPassed) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Score Circle
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isPassed ? const Color(0xFFE8F8F5) : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  scoreValue.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isPassed ? const Color(0xFF167B66) : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  '/10.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: isPassed ? const Color(0xFF28B79B) : const Color(0xFFEF4444).withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          
          // Exam and Attempt details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review: ${widget.exam.title}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPassed ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPassed ? 'PASSED' : 'FAILED',
                        style: TextStyle(
                          color: isPassed ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Attempt: #${widget.attempt['attemptNumber']}',
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_month, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      widget.attempt['date'] ?? '',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
        final options = q['options'] as List;
        final correctIndex = q['correctIndex'] as int;
        final userSelectedIndex = _userAnswers[index];
        final isCorrect = userSelectedIndex == correctIndex;

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

              // Question Text
              Text(
                'Question ${index + 1}: ${q['content']}',
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
                  final optionText = options[optIdx];
                  final isUserSelected = userSelectedIndex == optIdx;
                  final isOptionCorrect = correctIndex == optIdx;

                  Color optionBg = Colors.white;
                  Color optionBorder = Colors.grey.shade200;
                  Widget? suffixIcon;

                  if (isOptionCorrect) {
                    optionBg = const Color(0xFFE8F8F5);
                    optionBorder = const Color(0xFF28B79B);
                    suffixIcon = const Icon(Icons.check_circle, color: Color(0xFF28B79B), size: 18);
                  } else if (isUserSelected) {
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
                        // Radio circle mockup
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOptionCorrect
                                  ? const Color(0xFF28B79B)
                                  : (isUserSelected ? const Color(0xFFEF4444) : Colors.grey.shade400),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: (isOptionCorrect || isUserSelected)
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOptionCorrect ? const Color(0xFF28B79B) : const Color(0xFFEF4444),
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
                            color: isOptionCorrect
                                ? const Color(0xFF167B66)
                                : (isUserSelected ? const Color(0xFFEF4444) : const Color(0xFF4B5563)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(
                              color: isOptionCorrect
                                  ? const Color(0xFF167B66)
                                  : (isUserSelected ? const Color(0xFFEF4444) : const Color(0xFF1F2937)),
                              fontWeight: (isOptionCorrect || isUserSelected) ? FontWeight.bold : FontWeight.normal,
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
              final correctIndex = _examQuestions[index]['correctIndex'] as int;
              final userSelectedIndex = _userAnswers[index];
              final isCorrect = userSelectedIndex == correctIndex;

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
