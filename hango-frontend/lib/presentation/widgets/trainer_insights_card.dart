import 'package:flutter/material.dart';

class TrainerInsightsCard extends StatelessWidget {
  final String? title;
  final String? description;

  const TrainerInsightsCard({
    super.key,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      child: Stack(
        children: [
          // Background Watermark
          Positioned(
            right: -24,
            bottom: -24,
            child: Icon(
              Icons.lightbulb_outline,
              size: 120,
              color: const Color(0xFF20B486).withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B486).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Color(0xFF20B486),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title ?? 'Trainer Insights',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  description ??
                      'Engaging videos and clear syllabus help students stay motivated. Consider adding short quizzes after each section to reinforce learning.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
