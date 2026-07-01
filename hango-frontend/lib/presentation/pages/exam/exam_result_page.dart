import 'package:flutter/material.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../domain/model/course.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/shared_header.dart';
import '../course/course_detail_page.dart';
import 'exam_review_page.dart';
import 'list_exams_page.dart';

class ExamResultPage extends StatefulWidget {
  final Exam exam;
  final double score;
  final int correctCount;
  final int totalQuestions;
  final Map<int, int> userAnswers;
  final Map<String, dynamic> attempt;

  const ExamResultPage({
    Key? key,
    required this.exam,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.userAnswers,
    required this.attempt,
  }) : super(key: key);

  @override
  State<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends State<ExamResultPage> {
  final CourseRepository _courseRepository = CourseRepository();
  List<Course> _recommendedCourses = [];
  bool _isLoadingCourses = true;
  String _weakestSkill = "";
  Map<String, double> _skillAccuracies = {};
  List<Map<String, dynamic>> _attempts = [];
  bool _isLoadingAttempts = true;

  @override
  void initState() {
    super.initState();
    _analyzeSkills();
    _loadRecommendations();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    try {
      final repository = ExamRepository();
      final loadedAttempts = await repository.fetchExamAttempts(widget.exam.id);

      setState(() {
        _attempts = loadedAttempts;
        _isLoadingAttempts = false;
      });
    } catch (e) {
      debugPrint("Error loading exam history: $e");
      setState(() {
        _attempts = [];
        _isLoadingAttempts = false;
      });
    }
  }

  void _analyzeSkills() {
    // Generate questions matching exam's question count to match skill types
    final List<String> baseSkills = [
      "Grammar", "Grammar", "Vocabulary", "Grammar", "Grammar", 
      "Vocabulary", "Vocabulary", "Vocabulary", "Reading Comprehension", "Reading Comprehension"
    ];

    Map<String, int> totalPerSkill = {};
    Map<String, int> correctPerSkill = {};

    for (int i = 0; i < widget.totalQuestions; i++) {
      final skill = baseSkills[i % baseSkills.length];
      totalPerSkill[skill] = (totalPerSkill[skill] ?? 0) + 1;
      
      final correctIndex = _getMockCorrectIndex(i);
      if (widget.userAnswers[i] == correctIndex) {
        correctPerSkill[skill] = (correctPerSkill[skill] ?? 0) + 1;
      }
    }

    // Compute accuracies
    double lowestAccuracy = 1.1;
    String weakest = "English";

    totalPerSkill.forEach((skill, total) {
      int correct = correctPerSkill[skill] ?? 0;
      double accuracy = total > 0 ? (correct / total) : 0.0;
      _skillAccuracies[skill] = accuracy;

      if (accuracy < lowestAccuracy) {
        lowestAccuracy = accuracy;
        weakest = skill;
      }
    });

    setState(() {
      _weakestSkill = weakest;
    });
  }

  int _getMockCorrectIndex(int questionIndex) {
    final List<int> correctIndices = [2, 2, 1, 1, 2, 0, 0, 1, 2, 0];
    return correctIndices[questionIndex % correctIndices.length];
  }

  Future<void> _loadRecommendations() async {
    try {
      final courses = await _courseRepository.fetchCourses();
      
      // Filter courses matching weak skill category name or keywords
      List<Course> filtered = courses.where((c) {
        final titleLower = c.title.toLowerCase();
        final catLower = c.category.toLowerCase();
        final weakLower = _weakestSkill.toLowerCase();
        
        if (weakLower.contains("grammar")) {
          return titleLower.contains("grammar") || titleLower.contains("ngữ pháp") || catLower.contains("grammar");
        } else if (weakLower.contains("vocabulary")) {
          return titleLower.contains("vocabulary") || titleLower.contains("từ vựng") || titleLower.contains("word");
        } else if (weakLower.contains("reading")) {
          return titleLower.contains("reading") || titleLower.contains("đọc") || titleLower.contains("toeic");
        }
        return true;
      }).toList();

      // Fallback to top rated courses if none match category filter
      if (filtered.isEmpty) {
        filtered = List<Course>.from(courses);
        filtered.sort((a, b) => b.stars.compareTo(a.stars));
      }

      setState(() {
        _recommendedCourses = filtered.take(3).toList();
        _isLoadingCourses = false;
      });
    } catch (e) {
      debugPrint("Error loading recommendations: $e");
      setState(() {
        _isLoadingCourses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isPassed = widget.score >= 5.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Exams'),
      body: SingleChildScrollView(
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
                    // Result title
                    const Text(
                      'Exam Result',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Content layout
                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _buildResultDetails(isPassed),
                                    const SizedBox(height: 24),
                                    _buildAttemptHistoryCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(flex: 2, child: _buildRecommendationsPanel()),
                            ],
                          )
                        : Column(
                            children: [
                              _buildResultDetails(isPassed),
                              const SizedBox(height: 24),
                              _buildAttemptHistoryCard(),
                              const SizedBox(height: 32),
                              _buildRecommendationsPanel(),
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

  Widget _buildResultDetails(bool isPassed) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular Score Indicator
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPassed ? const Color(0xFFE8F8F5) : const Color(0xFFFEE2E2),
              border: Border.all(
                color: isPassed ? const Color(0xFF28B79B) : const Color(0xFFEF4444),
                width: 4,
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: isPassed ? const Color(0xFF167B66) : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  "/ 10 Score",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isPassed ? const Color(0xFF28B79B) : const Color(0xFFEF4444).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Passed/Failed Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isPassed ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              isPassed ? 'PASSED' : 'FAILED',
              style: TextStyle(
                color: isPassed ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Counts metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBox(Icons.quiz_outlined, 'Total', '${widget.totalQuestions}', Colors.grey.shade700),
              _buildStatBox(Icons.check_circle_outline, 'Correct', '${widget.correctCount}', const Color(0xFF10B981)),
              _buildStatBox(Icons.cancel_outlined, 'Incorrect', '${widget.totalQuestions - widget.correctCount}', const Color(0xFFEF4444)),
            ],
          ),
          const Divider(height: 48),

          // Skill breakdown progress bars
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Skill Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
            ),
          ),
          const SizedBox(height: 16),
          ..._skillAccuracies.entries.map((entry) {
            final skill = entry.key;
            final val = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        skill,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563)),
                      ),
                      Text(
                        '${(val * 100).toStringAsFixed(0)}% Accuracy',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: val,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        val >= 0.8
                            ? const Color(0xFF10B981)
                            : (val >= 0.5 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExamReviewPage(
                          exam: widget.exam,
                          attempt: widget.attempt,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Review Detailed Answers'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF28B79B),
                    side: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const ListExamsPage()),
                    );
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back to Exams List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(IconData icon, String label, String value, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildRecommendationsPanel() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Recommended Courses to Improve',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Our analysis shows you could improve in this skill area. We recommend these courses to help you succeed:',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Loader or List of Courses
          _isLoadingCourses
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48.0),
                    child: CircularProgressIndicator(color: Color(0xFF28B79B)),
                  ),
                )
              : _recommendedCourses.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Text(
                          'No suitable courses found.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ),
                    )
                  : Column(
                      children: _recommendedCourses.map((course) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Course Image/Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey.shade200,
                                  child: course.thumbnailUrl.isNotEmpty
                                      ? Image.network(
                                          course.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.book_outlined, color: Colors.grey),
                                        )
                                      : const Icon(Icons.book_outlined, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Course Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        course.category.toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF0369A1),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      course.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.star, color: Colors.amber.shade500, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${course.stars}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${course.difficulty}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CourseDetailPage(courseId: course.id),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF28B79B),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Learn Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  // Attempt history card
  Widget _buildAttemptHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attempt History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total attempts: ${_attempts.length}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 24),
          
          _isLoadingAttempts
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF28B79B))),
                  ),
                )
              : _attempts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              "No attempts yet.\nStart the exam to see your history.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attempts.length,
                      separatorBuilder: (context, index) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final attempt = _attempts[index];
                        final attemptNum = attempt['attemptNumber'] ?? (index + 1);
                        final date = attempt['date'] ?? '';
                        final score = (attempt['score'] as num?)?.toDouble() ?? 0.0;
                        final status = attempt['status'] ?? 'PASSED';
                        
                        final isPassed = score >= 5.0;

                        return Row(
                          children: [
                            // Circular attempt index indicator
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isPassed ? const Color(0xFFE8F8F5) : const Color(0xFFFEE2E2),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#$attemptNum',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPassed ? const Color(0xFF167B66) : const Color(0xFFEF4444),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Date and status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    date,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF374151)),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isPassed ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPassed ? 'PASSED' : 'FAILED',
                                      style: TextStyle(
                                        color: isPassed ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            
                            // Score display
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  score.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isPassed ? const Color(0xFF167B66) : const Color(0xFFEF4444),
                                  ),
                                ),
                                const Text(
                                  '/10.0',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                )
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Review button
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExamReviewPage(
                                      exam: widget.exam,
                                      attempt: attempt,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF28B79B),
                                side: const BorderSide(color: Color(0xFF28B79B)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Review',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
