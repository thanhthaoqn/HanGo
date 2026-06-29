import 'package:flutter/material.dart';

class LessonListWidget extends StatelessWidget {
  final List<dynamic> lessons;
  final VoidCallback onAddLessonPressed;
  final Function(int index) onEditLessonPressed;
  final Function(int index) onDeleteLessonPressed;

  const LessonListWidget({
    super.key,
    required this.lessons,
    required this.onAddLessonPressed,
    required this.onEditLessonPressed,
    required this.onDeleteLessonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lessons.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lessons.length,
            itemBuilder: (context, lessonIndex) {
              final lesson = lessons[lessonIndex];
              IconData lessonIcon = Icons.description_outlined;
              if (lesson['itemType'] == 'quiz' || lesson['itemType'] == 'practice') {
                lessonIcon = Icons.assignment_outlined;
              } else if (lesson['itemType'] == 'video') {
                lessonIcon = Icons.play_circle_outline;
              }

              final String itemTypeStr = (lesson['itemType'] as String? ?? 'TEXT').toUpperCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEFF2F5)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Teal vertical line indicator on the left
                      Container(
                        width: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF20B486),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Icon in light green/teal background
                      Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2F9F3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            lessonIcon,
                            color: const Color(0xFF20B486),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title, type badge, and description
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    lesson['title'] ?? 'Untitled Lesson',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      itemTypeStr,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF475569),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (lesson['description'] != null &&
                                  lesson['description'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  lesson['description'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Actions (Edit, Delete)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 18),
                            onPressed: () => onEditLessonPressed(lessonIndex),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            onPressed: () => onDeleteLessonPressed(lessonIndex),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        // + Add Lesson outline button
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAddLessonPressed,
            icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
            label: const Text(
              'Add Lesson',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF20B486),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF20B486)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        if (lessons.isNotEmpty) ...[
          const SizedBox(height: 16),
          // Pagination control matching mockup
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.chevron_left, color: Color(0xFF94A3B8), size: 18),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF20B486),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
            ],
          ),
        ],
      ],
    );
  }
}
