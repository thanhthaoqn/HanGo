import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../utils/fullscreen_helper.dart';
import 'package:go_router/go_router.dart';
import '../../../routes/app_routes.dart';
import 'exam_result_page.dart';

class TakeExamPage extends StatefulWidget {
  final Exam? exam;
  final String? examId;

  const TakeExamPage({super.key, this.exam, this.examId});

  @override
  State<TakeExamPage> createState() => _TakeExamPageState();
}

class _TakeExamPageState extends State<TakeExamPage>
    with SingleTickerProviderStateMixin {
  Exam? _exam;
  bool _isLoadingExam = false;
  String? _examError;
  int _durationInSeconds = 3000;
  int _timeLeft = 3000;
  Timer? _timer;
  int _currentQuestionIndex = 0;
  bool _isSubmitted = false;
  bool _isSubmitting = false;
  double _textScaleFactor = 1.0;

  // Answers cache: questionIndex -> selectedOptionIndex (0 to 3)
  Map<int, int> _userAnswers = {};

  // Custom scroll controllers for question grid and question content
  final ScrollController _gridScrollController = ScrollController();
  final ScrollController _contentScrollController = ScrollController();

  // Animation controller for blinking red timer
  AnimationController? _timerAnimationController;
  Animation<double>? _timerScaleAnimation;

  late List<Map<String, dynamic>> _examQuestions = [];
  late List<Map<String, dynamic>> _examGroups = [];
  bool _isLoading = true;
  final ExamRepository _examRepository = ExamRepository();

  @override
  void initState() {
    super.initState();
    if (widget.exam != null) {
      _exam = widget.exam;
      _loadQuestions();
    } else if (widget.examId != null) {
      _fetchExam();
    }
  }

  Future<void> _fetchExam() async {
    setState(() {
      _isLoadingExam = true;
      _examError = null;
    });
    try {
      final fetched = await _examRepository.fetchExamById(widget.examId!);
      if (mounted) {
        setState(() {
          _exam = fetched;
          _isLoadingExam = false;
        });
        _loadQuestions();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingExam = false;
          _examError = e.toString();
        });
      }
    }
  }

  Future<void> _loadQuestions() async {
    final examId = _exam?.id ?? widget.exam?.id ?? widget.examId;
    if (examId == null || examId.isEmpty) return;
    try {
      final questions = await _examRepository.fetchExamQuestions(
        examId,
      );

      final Map<int, List<Map<String, dynamic>>> groupMap = {};
      final List<Map<String, dynamic>> flatQuestions = [];

      int globalQIndex = 0;
      for (var q in questions) {
        final processedQ = {
          "id": q['id'],
          "globalIndex": globalQIndex,
          "content": "Question ${globalQIndex + 1}: ${q['content']}",
          "options": (q['options'] as List)
              .map((o) => o['optionText'])
              .toList(),
          "skill": q['skill'],
        };

        flatQuestions.add(processedQ);

        final group = q['group'];
        int groupId = group != null ? group['id'] : -1 - globalQIndex;
        if (!groupMap.containsKey(groupId)) {
          groupMap[groupId] = [];
        }
        groupMap[groupId]!.add(processedQ);

        globalQIndex++;
      }

      final List<Map<String, dynamic>> groups = [];
      for (var entry in groupMap.entries) {
        String? passage;
        if (entry.key >= 0) {
          final firstQ = questions.firstWhere(
            (q) => q['group'] != null && q['group']['id'] == entry.key,
          );
          passage = firstQ['group']['passage'];
        }
        groups.add({"passage": passage, "questions": entry.value});
      }

      if (mounted) {
        setState(() {
          _examQuestions = flatQuestions;
          _examGroups = groups;
          _isLoading = false;
        });
        _initializeTimer();
      }
    } catch (e) {
      debugPrint("Error loading questions: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load questions.')));
      }
    }
  }

  void _initializeTimer() {
    // Set duration
    final currentDuration = _exam?.durationMinutes ?? widget.exam?.durationMinutes ?? 0;
    int durationMinutes = currentDuration > 0
        ? currentDuration
        : 50;
    _durationInSeconds = durationMinutes * 60;
    _timeLeft = _durationInSeconds;

    // Timer animations
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _timerScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _timerAnimationController!,
        curve: Curves.easeInOut,
      ),
    );

    _loadCachedAnswers();
    _startTimer();

    // Trigger fullscreen mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      toggleFullscreen(true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerAnimationController?.dispose();
    _gridScrollController.dispose();
    _contentScrollController.dispose();
    // Exit fullscreen mode
    toggleFullscreen(false);
    super.dispose();
  }

  String get _currentExamId => _exam?.id ?? widget.exam?.id ?? widget.examId ?? '';

  // Load answers from local cache (SharedPreferences)
  Future<void> _loadCachedAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'take_exam_$_currentExamId';
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        setState(() {
          _userAnswers = decoded.map(
            (key, value) => MapEntry(int.parse(key), value as int),
          );
        });
      }
    } catch (e) {
      debugPrint("Error loading cached exam answers: $e");
    }
  }

  // Save answers to local cache
  Future<void> _saveAnswersToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'take_exam_$_currentExamId';
      final Map<String, String> stringified = _userAnswers.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      await prefs.setString(cacheKey, jsonEncode(stringified));
    } catch (e) {
      debugPrint("Error caching exam answers: $e");
    }
  }

  // Clear cache for this exam
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'take_exam_$_currentExamId';
      await prefs.remove(cacheKey);
    } catch (e) {
      debugPrint("Error clearing cached answers: $e");
    }
  }

  // Timer logic
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
          // Start blinking timer when less than 2 minutes remain (120s)
          if (_timeLeft <= 120) {
            if (_timerAnimationController != null &&
                !_timerAnimationController!.isAnimating) {
              _timerAnimationController!.repeat(reverse: true);
            }
          }
        });
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    String minStr = minutes.toString().padLeft(2, '0');
    String secStr = seconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  void _selectAnswer(int questionIndex, int optionIndex) {
    setState(() {
      _userAnswers[questionIndex] = optionIndex;
    });
    _saveAnswersToCache();
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _isSubmitted = true;
    });
    _timer?.cancel();
    _clearCache();

    try {
      final attemptMap = await _saveAttemptToHistory();
      double score = 0.0;
      if (attemptMap != null && attemptMap['score'] != null) {
        score = (attemptMap['score'] as num).toDouble();
      }

      int correctCount = (score * _examQuestions.length / 10).round();
      if (attemptMap != null && attemptMap['correctness'] is Map) {
        final correctness = attemptMap['correctness'] as Map;
        correctCount = correctness.values.where((v) => v == true).length;
      }

      final currentExam = _exam ?? widget.exam;
      final resultExtra = {
        'exam': currentExam,
        'score': score,
        'correctCount': correctCount,
        'examQuestions': _examQuestions,
        'userAnswers': _userAnswers,
        'attempt': attemptMap ??
            {
              "attemptNumber": 1,
              "date": DateTime.now()
                  .toString()
                  .substring(0, 16)
                  .replaceFirst('T', ' '),
              "score": score,
              "status": score >= 5.0 ? "PASSED" : "FAILED",
              "answers": _userAnswers.map(
                (key, value) => MapEntry((key + 1).toString(), value),
              ),
              "correctness": {},
            },
      };

      if (!mounted) return;
      try {
        context.go(
          AppRoutes.examResult,
          extra: resultExtra,
        );
      } catch (e) {
        debugPrint("GoRouter navigation to examResult failed, fallback: $e");
      }
      if (mounted && currentExam != null) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ExamResultPage(
              exam: currentExam,
              score: score,
              correctCount: correctCount,
              examQuestions: _examQuestions,
              userAnswers: _userAnswers,
              attempt: resultExtra['attempt'] as Map<String, dynamic>,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error during exam submit: $e");
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = false;
        });
        if (_timeLeft > 0) {
          _startTimer();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit exam: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autoSubmit() async {
    if (_isSubmitted || _isSubmitting) return;
    await _submitExam();
  }

  void _confirmSubmit() {
    if (_isSubmitting) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 10,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F7F4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: Color(0xFF28B79B),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Submission',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to submit your test? You have answered ${_userAnswers.length} of ${_examQuestions.length} questions.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        _submitExam();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _saveAttemptToHistory() async {
    try {
      final repository = ExamRepository();
      Map<String, dynamic> answersForSubmit = {};
      _userAnswers.forEach((key, value) {
        answersForSubmit[(key + 1).toString()] = value;
      });
      final examId = _currentExamId;
      if (examId.isEmpty) return null;
      final attempt = await repository.submitExamAttempt(
        examId,
        0.0,
        answersForSubmit,
      );
      return attempt;
    } catch (e) {
      debugPrint("Error saving attempt: $e");
      return null;
    }
  }

  void _showExitExamConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 10,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quit Test?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to leave? Your progress will be saved, but the timer will keep counting down if you leave.',
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
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Resume',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close confirm
                        final examSlug = _exam?.uuid ?? widget.exam?.uuid ?? _currentExamId;
                        if (examSlug.isNotEmpty) {
                          context.go(AppRoutes.examDetailRoute(examSlug), extra: _exam ?? widget.exam);
                        } else {
                          context.go(AppRoutes.exams);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Quit',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassageWithBlanks(String passageText, List<dynamic> groupQuestions) {
    // Regex hỗ trợ các định dạng: _________, ___(1)___, ___ 1 ___, ___[1]___
    final regex = RegExp(r'_{2,}\s*(?:\(\d+\)|\[\d+\]|\d+)?\s*_{2,}|_{3,}');
    final matches = regex.allMatches(passageText).toList();
    
    if (matches.isEmpty) {
      return Text(
        passageText,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF334155),
          height: 1.6,
        ),
      );
    }

    List<InlineSpan> spans = [];
    int currentPos = 0;
    int blankIndex = 0;

    for (final match in matches) {
      // Add text before the blank
      if (match.start > currentPos) {
        spans.add(TextSpan(text: passageText.substring(currentPos, match.start)));
      }

      // Determine if this blank corresponds to a question in the group
      if (blankIndex < groupQuestions.length) {
        final q = groupQuestions[blankIndex];
        final globalQIndex = q['globalIndex'] as int;
        final selectedOptionIndex = _userAnswers[globalQIndex];

        if (selectedOptionIndex != null && selectedOptionIndex >= 0 && selectedOptionIndex < q['options'].length) {
          // User has selected an answer, display the answer text
          final answerText = q['options'][selectedOptionIndex];
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * _textScaleFactor, vertical: 4 * _textScaleFactor),
                margin: EdgeInsets.symmetric(horizontal: 4 * _textScaleFactor),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F5),
                  border: Border(bottom: BorderSide(color: const Color(0xFF28B79B), width: 2 * _textScaleFactor)),
                  borderRadius: BorderRadius.circular(4 * _textScaleFactor),
                ),
                child: Text(
                  answerText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF167B66),
                  ),
                ),
              ),
            ),
          );
        } else {
          // Display the original underscores
          spans.add(
            TextSpan(
              text: match.group(0),
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          );
        }
      } else {
        // Extra blanks that don't have corresponding questions
        spans.add(TextSpan(text: match.group(0)));
      }

      currentPos = match.end;
      blankIndex++;
    }

    // Add remaining text after the last blank
    if (currentPos < passageText.length) {
      spans.add(TextSpan(text: passageText.substring(currentPos)));
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF334155),
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildExitExamHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _showExitExamConfirmation,
              child: Row(
                children: const [
                  Icon(Icons.arrow_back, size: 20, color: Color(0xFF1E293B)),
                  SizedBox(width: 8),
                  Text(
                    'Exit Exam',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamTopBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF28B79B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Question ${_currentQuestionIndex + 1} / ${_examQuestions.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF28B79B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Color(0xFF28B79B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_userAnswers.length} done',
                      style: const TextStyle(
                        color: Color(0xFF28B79B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Countdown Timer!
          AnimatedBuilder(
            animation: _timerScaleAnimation!,
            builder: (context, child) {
              final isWarning = _timeLeft <= 120;
              final timeStr = _formatTime(_timeLeft);
              return Transform.scale(
                scale: isWarning ? _timerScaleAnimation!.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isWarning
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFE8F8F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isWarning
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF28B79B),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isWarning
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF167B66),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isWarning
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF167B66),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExamActiveQuestionPane(bool isDesktop) {
    final currentQuestion = _examQuestions[_currentQuestionIndex];

    // Find passage if exists
    String? passageText;
    List<dynamic>? groupQuestions;
    for (var group in _examGroups) {
      final List qs = group['questions'];
      if (qs.any((q) => q['id'] == currentQuestion['id'])) {
        passageText = group['passage'];
        groupQuestions = qs;
        break;
      }
    }

    final zoomableContent = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(MediaQuery.of(context).textScaler.scale(1.0) * _textScaleFactor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passage text if available
          if (passageText != null && passageText.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(16 * _textScaleFactor),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8 * _textScaleFactor),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _buildPassageWithBlanks(passageText, groupQuestions ?? []),
            ),
            SizedBox(height: 24 * _textScaleFactor),
          ],

          // Question text
          Text(
            currentQuestion['content'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              height: 1.4,
            ),
          ),
          SizedBox(height: 32 * _textScaleFactor),

          // Option cards
          ...List.generate(4, (index) {
            final isSelected =
                _userAnswers[_currentQuestionIndex] == index;
            final optionLabel = String.fromCharCode(
              65 + index,
            ); // A, B, C, D
            final optionText = currentQuestion['options'][index];

            return Padding(
              padding: EdgeInsets.only(bottom: 16.0 * _textScaleFactor),
              child: InkWell(
                onTap: () =>
                    _selectAnswer(_currentQuestionIndex, index),
                borderRadius: BorderRadius.circular(12 * _textScaleFactor),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * _textScaleFactor,
                    vertical: 16 * _textScaleFactor,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE8F8F5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12 * _textScaleFactor),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF28B79B)
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: const Color(
                            0xFF28B79B,
                          ).withValues(alpha: 0.1),
                          blurRadius: 10 * _textScaleFactor,
                          offset: Offset(0, 4 * _textScaleFactor),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4 * _textScaleFactor,
                          offset: Offset(0, 2 * _textScaleFactor),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Circle label (A, B, C, D)
                      Container(
                        width: 32 * _textScaleFactor,
                        height: 32 * _textScaleFactor,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF28B79B)
                              : Colors.grey.shade100,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          optionLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      SizedBox(width: 16 * _textScaleFactor),
                      // Option Text
                      Expanded(
                        child: Text(
                          optionText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF1E293B)
                                : Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // Radio checklist indicator
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: const Color(0xFF28B79B),
                          size: 22 * _textScaleFactor,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );

    final contentBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skill header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                currentQuestion['skill'].toString().toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF94A3B8)),
                  tooltip: 'Thu nhỏ chữ',
                  onPressed: () {
                    setState(() {
                      if (_textScaleFactor > 0.6) _textScaleFactor -= 0.1;
                    });
                  },
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(_textScaleFactor * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF94A3B8)),
                  tooltip: 'Phóng to chữ',
                  onPressed: () {
                    setState(() {
                      if (_textScaleFactor < 1.6) _textScaleFactor += 0.1;
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_examQuestions.length}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        zoomableContent,
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            Expanded(
              child: SingleChildScrollView(
                controller: _contentScrollController,
                child: contentBody,
              ),
            )
          else
            contentBody,
          const SizedBox(height: 16),
          // Bottom Navigation Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _currentQuestionIndex > 0
                    ? () => setState(() => _currentQuestionIndex--)
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: const Color(0xFF28B79B),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  side: BorderSide(color: Colors.grey.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _currentQuestionIndex < _examQuestions.length - 1
                    ? () => setState(() => _currentQuestionIndex++)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF28B79B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamRightSidebarPane(bool isDesktop) {
    final gridContent = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_examQuestions.length, (index) {
        final isAnswered = _userAnswers.containsKey(index);
        final isActive = _currentQuestionIndex == index;

        Color bgColor = Colors.white;
        Color borderColor = Colors.grey.shade200;
        Color textColor = Colors.grey.shade700;

        if (isActive) {
          bgColor = Colors.white;
          borderColor = const Color(0xFF28B79B);
          textColor = const Color(0xFF28B79B);
        } else if (isAnswered) {
          bgColor = const Color(0xFFE8F8F5);
          borderColor = const Color(0xFF28B79B).withValues(alpha: 0.5);
          textColor = const Color(0xFF167B66);
        }

        return InkWell(
          onTap: () => setState(() => _currentQuestionIndex = index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: isActive ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 14,
              ),
            ),
          ),
        );
      }),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Progress Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Answered: ${_userAnswers.length} / ${_examQuestions.length}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Question Grid
          if (isDesktop)
            Expanded(
              child: SingleChildScrollView(
                controller: _gridScrollController,
                child: gridContent,
              ),
            )
          else
            gridContent,
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _confirmSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Submit Exam',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: null,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isLoadingExam || _isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF28B79B)),
              )
            else if (_examError != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Failed to load exam: $_examError',
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchExam,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _buildExitExamHeader(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildExamTopBar(isDesktop),
                          const SizedBox(height: 16),
                          Expanded(
                            child: isDesktop
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 7,
                                        child:
                                            _buildExamActiveQuestionPane(true),
                                      ),
                                      const SizedBox(width: 24),
                                      SizedBox(
                                        width: 320,
                                        child: _buildExamRightSidebarPane(true),
                                      ),
                                    ],
                                  )
                                : SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        _buildExamActiveQuestionPane(false),
                                        const SizedBox(height: 24),
                                        _buildExamRightSidebarPane(false),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            if (_isSubmitting)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(
                          color: Color(0xFF28B79B),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Submitting Exam...',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Grading your test, please wait a moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
