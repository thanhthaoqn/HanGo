import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../widgets/learning_pathway/pathway_setup_dialog.dart';
import '../../../utils/fullscreen_helper.dart';
import 'exam_result_page.dart';
import '../../widgets/exam/entry_exam_goal_dialog.dart';
class TakeExamPage extends StatefulWidget {
  final Exam exam;

  const TakeExamPage({Key? key, required this.exam}) : super(key: key);

  @override
  State<TakeExamPage> createState() => _TakeExamPageState();
}

class _TakeExamPageState extends State<TakeExamPage> with SingleTickerProviderStateMixin {
  late int _durationInSeconds;
  late int _timeLeft;
  Timer? _timer;
  int _currentQuestionIndex = 0;
  bool _isSubmitted = false;

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
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _examRepository.fetchExamQuestions(widget.exam.id);
      
      final Map<int, List<Map<String, dynamic>>> groupMap = {};
      final List<Map<String, dynamic>> flatQuestions = [];
      
      int globalQIndex = 0;
      for (var q in questions) {
        final processedQ = {
          "id": q['id'],
          "globalIndex": globalQIndex,
          "content": "Question ${globalQIndex + 1}: ${q['content']}",
          "options": (q['options'] as List).map((o) => o['optionText']).toList(),
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
          final firstQ = questions.firstWhere((q) => q['group'] != null && q['group']['id'] == entry.key);
          passage = firstQ['group']['passage'];
        }
        groups.add({
          "passage": passage,
          "questions": entry.value,
        });
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load questions.')));
      }
    }
  }

  void _initializeTimer() {
    // Set duration
    int durationMinutes = widget.exam.durationMinutes > 0 ? widget.exam.durationMinutes : 50;
    _durationInSeconds = durationMinutes * 60;
    _timeLeft = _durationInSeconds;

    // Timer animations
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _timerScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _timerAnimationController!, curve: Curves.easeInOut),
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

  // Load answers from local cache (SharedPreferences)
  Future<void> _loadCachedAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'take_exam_${widget.exam.id}';
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        setState(() {
          _userAnswers = decoded.map((key, value) => MapEntry(int.parse(key), value as int));
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
      final cacheKey = 'take_exam_${widget.exam.id}';
      final Map<String, String> stringified = _userAnswers.map((key, value) => MapEntry(key.toString(), value.toString()));
      await prefs.setString(cacheKey, jsonEncode(stringified));
    } catch (e) {
      debugPrint("Error caching exam answers: $e");
    }
  }

  // Clear cache for this exam
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'take_exam_${widget.exam.id}';
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
            if (_timerAnimationController != null && !_timerAnimationController!.isAnimating) {
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

  Future<void> _autoSubmit() async {
    if (_isSubmitted) return;
    _clearCache();
    setState(() {
      _isSubmitted = true;
    });
    
    final attemptMap = await _saveAttemptToHistory();
    double score = 0.0;
    if (attemptMap != null && attemptMap['score'] != null) {
      score = (attemptMap['score'] as num).toDouble();
    }
    
    int correctCount = (score * _examQuestions.length / 10).round();
    
    await _maybeRefreshPathway(attemptMap);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ExamResultPage(
          exam: widget.exam,
          score: score,
          correctCount: correctCount,
          totalQuestions: _examQuestions.length,
          userAnswers: _userAnswers,
          attempt: attemptMap ?? {
            "attemptNumber": 1,
            "date": DateTime.now().toString().substring(0, 16).replaceFirst('T', ' '),
            "score": score,
            "status": score >= 5.0 ? "PASSED" : "FAILED",
            "answers": _userAnswers.map((key, value) => MapEntry((key + 1).toString(), value)),
          },
        ),
      ),
    );
  }

  void _confirmSubmit() {
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
                      onPressed: () => Navigator.pop(context),
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
                      onPressed: () async {
                        Navigator.pop(context); // Close confirm dialog
                        _clearCache();
                        setState(() {
                          _isSubmitted = true;
                        });
                        _timer?.cancel();
                        
                        final attemptMap = await _saveAttemptToHistory();
                        double score = 0.0;
                        if (attemptMap != null && attemptMap['score'] != null) {
                          score = (attemptMap['score'] as num).toDouble();
                        }
                        int correctCount = (score * _examQuestions.length / 10).round();
                        
                        if (widget.exam.id == '60') {
                          if (!mounted) return;
                          
                          final rawAttemptId = attemptMap?['id'];
                          final attemptId = rawAttemptId is int ? rawAttemptId : int.tryParse('$rawAttemptId') ?? 0;
                          
                          showDialog(
                            context: this.context,
                            barrierDismissible: false,
                            builder: (ctx) => EntryExamGoalDialog(
                              currentScore: score,
                              attemptId: attemptId,
                            ),
                          );
                        } else {
                          await _maybeRefreshPathway(attemptMap);
                          if (!mounted) return;

                          Navigator.pushReplacement(
                            this.context,
                            MaterialPageRoute(
                              builder: (context) => ExamResultPage(
                                exam: widget.exam,
                                score: score,
                                correctCount: correctCount,
                                totalQuestions: _examQuestions.length,
                                userAnswers: _userAnswers,
                                attempt: attemptMap ?? {
                                  "attemptNumber": 1,
                                  "date": DateTime.now().toString().substring(0, 16).replaceFirst('T', ' '),
                                  "score": score,
                                  "status": score >= 5.0 ? "PASSED" : "FAILED",
                                  "answers": _userAnswers.map((key, value) => MapEntry((key + 1).toString(), value)),
                                },
                              ),
                            ),
                          );
                        }
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

  Future<Map<String, dynamic>?> _saveAttemptToHistory() async {
    try {
      final repository = ExamRepository();
      Map<String, dynamic> answersForSubmit = {};
      _userAnswers.forEach((key, value) {
        answersForSubmit[(key + 1).toString()] = value;
      });
      final attempt = await repository.submitExamAttempt(widget.exam.id, 0.0, answersForSubmit);
      return attempt;
    } catch (e) {
      debugPrint("Error saving attempt: $e");
      return null;
    }
  }

  Future<void> _maybeRefreshPathway(Map<String, dynamic>? attemptMap) async {
    final rawAttemptId = attemptMap?['id'];
    final attemptId = rawAttemptId is int ? rawAttemptId : int.tryParse('$rawAttemptId');
    if (attemptId == null || attemptId <= 0 || !mounted) return;

    final pathwayRepository = PathwayRepository();
    var hasCurrentPathway = false;
    try {
      await pathwayRepository.getMyPathway();
      hasCurrentPathway = true;
    } catch (_) {
      hasCurrentPathway = false;
    }

    if (!mounted) return;
    if (!hasCurrentPathway) {
      final setupData = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PathwaySetupDialog(examAttemptId: attemptId),
      );
      if (setupData == null) return; // Cancelled

      try {
        await pathwayRepository.generatePathway(
          examAttemptId: attemptId,
          goalName: setupData['goalName'],
          targetDate: setupData['targetDate'],
          hoursPerWeek: setupData['hoursPerWeek'],
        );
      } catch (e) {
        debugPrint("Error generating first pathway: $e");
      }
      return;
    }

    final shouldRefresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF28B79B)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Update your learning pathway?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This exam gives AI a fresher signal. You can update the pathway now or keep your current route unchanged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Keep current'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28B79B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Update now'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shouldRefresh == true) {
      final setupData = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PathwaySetupDialog(examAttemptId: attemptId),
      );
      if (setupData == null) return; // Cancelled

      try {
        await pathwayRepository.generatePathway(
          examAttemptId: attemptId,
          goalName: setupData['goalName'],
          targetDate: setupData['targetDate'],
          hoursPerWeek: setupData['hoursPerWeek'],
        );
      } catch (e) {
        debugPrint("Error refreshing pathway after exam: $e");
      }
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
                        Navigator.pop(context); // Close take exam screen
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
                    color: const Color(0xFF28B79B).withOpacity(0.3),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isWarning ? const Color(0xFFFEE2E2) : const Color(0xFFE8F8F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isWarning ? const Color(0xFFFCA5A5) : const Color(0xFF28B79B),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: isWarning ? const Color(0xFFEF4444) : const Color(0xFF167B66),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isWarning ? const Color(0xFFEF4444) : const Color(0xFF167B66),
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

  Widget _buildExamActiveQuestionPane() {
    final currentQuestion = _examQuestions[_currentQuestionIndex];
    
    // Find passage if exists
    String? passageText;
    for (var group in _examGroups) {
      final List qs = group['questions'];
      if (qs.any((q) => q['id'] == currentQuestion['id'])) {
        passageText = group['passage'];
        break;
      }
    }

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
          Expanded(
            child: SingleChildScrollView(
              controller: _contentScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skill header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentQuestion['skill'].toString().toUpperCase(),
                          style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${_examQuestions.length}',
                        style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Passage text if available
                  if (passageText != null && passageText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        passageText,
                        style: const TextStyle(fontSize: 16, color: Color(0xFF334155), height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Question text
                  Text(
                    currentQuestion['content'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // Option cards
                  ...List.generate(4, (index) {
                    final isSelected = _userAnswers[_currentQuestionIndex] == index;
                    final optionLabel = String.fromCharCode(65 + index); // A, B, C, D
                    final optionText = currentQuestion['options'][index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () => _selectAnswer(_currentQuestionIndex, index),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE8F8F5) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF28B79B) : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: const Color(0xFF28B79B).withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              else
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                            ],
                          ),
                          child: Row(
                            children: [
                              // Circle label (A, B, C, D)
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? const Color(0xFF28B79B) : Colors.grey.shade100,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  optionLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Option text
                              Expanded(
                                child: Text(
                                  optionText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF167B66) : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              // Radio checklist indicator
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFF28B79B), size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  side: BorderSide(color: Colors.grey.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamRightSidebarPane() {
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
          Expanded(
            child: SingleChildScrollView(
              controller: _gridScrollController,
              child: Wrap(
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
                    borderColor = const Color(0xFF28B79B).withOpacity(0.5);
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
                        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
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
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _confirmSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF28B79B)),
              )
            : Column(
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _buildExamActiveQuestionPane(),
                                ),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 320,
                                  child: _buildExamRightSidebarPane(),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildExamActiveQuestionPane(),
                                  const SizedBox(height: 24),
                                  _buildExamRightSidebarPane(),
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
      ),
    );
  }
}
