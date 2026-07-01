import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/exam.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/shared_header.dart';
import '../login_page.dart';
import 'take_exam_page.dart';
import 'exam_review_page.dart';

class ExamDetailHistoryPage extends StatefulWidget {
  final Exam exam;

  const ExamDetailHistoryPage({Key? key, required this.exam}) : super(key: key);

  @override
  State<ExamDetailHistoryPage> createState() => _ExamDetailHistoryPageState();
}

class _ExamDetailHistoryPageState extends State<ExamDetailHistoryPage> {
  List<Map<String, dynamic>> _attempts = [];
  bool _isLoadingAttempts = true;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  // Load attempt history from Backend API
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

  // Trigger when returning from TakeExamPage to refresh attempt list
  void _onExamCompleted() {
    _loadAttempts();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

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
                            'Back to Exams List',
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

                    // Layout split (Desktop: 2 columns, Mobile: 1 column)
                    isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildExamDetailCard(),
                                    const SizedBox(height: 24),
                                    _buildAttemptHistoryCard(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 2,
                                child: _buildNoticeInstructionsCard(),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildExamDetailCard(),
                              const SizedBox(height: 24),
                              _buildNoticeInstructionsCard(),
                              const SizedBox(height: 24),
                              _buildAttemptHistoryCard(),
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

  // Main detail card
  Widget _buildExamDetailCard() {
    return Container(
      padding: const EdgeInsets.all(32.0),
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
          // Badge & Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRACTICE EXAM',
                  style: TextStyle(
                    color: Color(0xFF28B79B),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    widget.exam.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    ' (${widget.exam.learnerCountFormatted})',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            widget.exam.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Creator
          Text(
            'Created by: ${widget.exam.creatorName}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 20),

          // Stat boxes
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  Icons.assignment_outlined,
                  '${widget.exam.questionCount} Questions',
                  'Sentences total',
                  const Color(0xFF3B82F6),
                  const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  Icons.access_time_outlined,
                  '${widget.exam.durationMinutes} Minutes',
                  'Time limit limit',
                  const Color(0xFFD97706),
                  const Color(0xFFFFFDF0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Description
          if (widget.exam.description.isNotEmpty) ...[
            const Text(
              'About this exam',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              widget.exam.description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String title, String subtitle, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937)),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Notice and start test panel
  Widget _buildNoticeInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEBFDF9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF28B79B).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFF167B66), size: 22),
              SizedBox(width: 8),
              Text(
                'Notice & Instructions',
                style: TextStyle(
                  color: Color(0xFF167B66),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The time will start counting down. When there are 2 minutes left, the clock will turn red. You should choose your answers for the remaining questions and submit your answers. You cannot change your answers after the time is up. Your results will appear after you press Submit.',
            style: TextStyle(
              color: Color(0xFF1F5F51),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('auth_token');
                if (token == null || token.isEmpty) {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TakeExamPage(exam: widget.exam),
                      ),
                    ).then((_) => _onExamCompleted());
                  }
                }
              },
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: Text(
                _attempts.isEmpty ? 'Start Exam' : 'Retake Exam',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
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
                                'Xem lại',
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
