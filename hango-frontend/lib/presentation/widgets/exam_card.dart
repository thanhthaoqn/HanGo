import 'package:flutter/material.dart';
import '../../../domain/entities/exam.dart';
import '../../../utils/language_manager.dart';
import '../pages/exam/exam_detail_history_page.dart';

class ExamCard extends StatefulWidget {
  final Exam exam;
  const ExamCard({Key? key, required this.exam}) : super(key: key);

  @override
  State<ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<ExamCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageManager.isVi;
    final isMinhHoa = widget.exam.title.toLowerCase().contains('minh họa') || 
                      widget.exam.title.toLowerCase().contains('minh hoa');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamDetailHistoryPage(exam: widget.exam),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? (Matrix4.identity()
                  ..translate(0, -6, 0)
                  ..scale(1.02))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? const Color(0xFF28B79B) : const Color(0xFFE5E7EB),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? const Color(0x1A28B79B) : const Color(0x0A000000),
                blurRadius: _isHovered ? 12 : 6,
                offset: _isHovered ? const Offset(0, 8) : const Offset(0, 3),
              )
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FFFA),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 12,
                            color: Color(0xFF28B79B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMinhHoa
                                ? (isVi ? 'Đề minh họa' : 'Mock exam')
                                : (isVi ? 'Đề chính thức' : 'Official exam'),
                            style: const TextStyle(
                              color: Color(0xFF137333),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title Section
                Expanded(
                  child: Text(
                    widget.exam.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Card Footer with question count and duration details
                Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVi ? '${widget.exam.questionCount} câu hỏi' : '${widget.exam.questionCount} questions',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVi ? '${widget.exam.durationMinutes} phút' : '${widget.exam.durationMinutes} mins',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
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
  }
}
