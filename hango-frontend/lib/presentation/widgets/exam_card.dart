import 'package:flutter/material.dart';
import '../../../domain/entities/exam.dart';

class ExamCard extends StatefulWidget {
  final Exam exam;
  const ExamCard({Key? key, required this.exam}) : super(key: key);

  @override
  State<ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<ExamCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: isHovered
                  ? Colors.black.withOpacity(0.12)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isHovered ? 20 : 10,
              offset: Offset(0, isHovered ? 10 : 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header with Banner Style
            Container(
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E8D77), Color(0xFF0F5A47)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 28.0, bottom: 12.0),
                    child: Text(
                      widget.exam.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ),

                  // EXAM Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EXAM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  
                  // Mortarboard watermark icon
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 68,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            
            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exam.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created By: ${widget.exam.creatorName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    
                    // Question / Sentence count & time duration details
                    Row(
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 13, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.exam.questionCount} sentences',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                        const Spacer(),
                        const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.exam.durationMinutes} minute',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Stars and learner count
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            Icons.star,
                            size: 12,
                            color: index < widget.exam.rating.floor() 
                                ? const Color(0xFFFBBF24) 
                                : Colors.grey.shade300,
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          widget.exam.learnerCountFormatted,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
