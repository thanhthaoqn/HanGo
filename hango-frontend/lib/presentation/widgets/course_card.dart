import 'package:flutter/material.dart';
import '../../../domain/model/course.dart';

class CourseCard extends StatefulWidget {
  final Course course;
  const CourseCard({Key? key, required this.course}) : super(key: key);

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
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
                  colors: [Color(0xFF32C6A9), Color(0xFF279E87)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.course.category,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ),
                  
                  // Mortarboard watermark icon
                  Positioned(
                    bottom: -15,
                    right: -10,
                    child: Icon(
                      Icons.school,
                      size: 80,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
            
            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created By: ${widget.course.creatorName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const Spacer(),
                    
                    // Stars and learner count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                Icons.star,
                                size: 12,
                                color: index < widget.course.stars.floor() 
                                    ? const Color(0xFFFBBF24) 
                                    : Colors.grey.shade300,
                              );
                            }),
                          ],
                        ),
                        Text(
                          '${widget.course.learnerCount} Learner',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Difficulty
                    Text(
                      widget.course.difficulty.toUpperCase() == 'BASIC' ? 'Basic' :
                      widget.course.difficulty.toUpperCase() == 'INTERMEDIATE' ? 'Intermediate' :
                      widget.course.difficulty.toUpperCase() == 'ADVANCED' ? 'Advanced' :
                      widget.course.difficulty,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1F2937),
                      ),
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
