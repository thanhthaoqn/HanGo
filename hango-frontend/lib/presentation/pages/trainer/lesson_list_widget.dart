import 'package:flutter/material.dart';

class LessonListWidget extends StatefulWidget {
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
  State<LessonListWidget> createState() => _LessonListWidgetState();
}

class _LessonListWidgetState extends State<LessonListWidget> {
  int _currentPage = 0;
  static const int _pageSize = 8;

  @override
  void didUpdateWidget(covariant LessonListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Normalize page index if list size changes (e.g. items deleted)
    final totalPages = (widget.lessons.length / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (widget.lessons.length / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize < widget.lessons.length)
        ? startIndex + _pageSize
        : widget.lessons.length;
    final paginatedLessons = widget.lessons.isNotEmpty
        ? widget.lessons.sublist(startIndex, endIndex)
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (paginatedLessons.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paginatedLessons.length,
            itemBuilder: (context, lessonIndex) {
              final originalIndex = startIndex + lessonIndex;
              final lesson = paginatedLessons[lessonIndex];
              final bool isQuiz = lesson['itemType'] == 'quiz' || lesson['itemType'] == 'practice';
              final bool isVideo = lesson['itemType'] == 'video';

              IconData lessonIcon = Icons.description_outlined;
              if (isQuiz) {
                lessonIcon = Icons.assignment_outlined;
              } else if (isVideo) {
                lessonIcon = Icons.play_circle_outline;
              }

              final String itemTypeStr = (lesson['itemType'] as String? ?? 'TEXT').toUpperCase();

              // Premium color palettes based on item type
              final Color themeColor = isQuiz
                  ? const Color(0xFF8B5CF6) // Purple/Violet
                  : isVideo
                      ? const Color(0xFF3B82F6) // Blue
                      : const Color(0xFF20B486); // Teal/Green

              final Color iconBgColor = isQuiz
                  ? const Color(0xFFF5F3FF)
                  : isVideo
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFE2F9F3);

              final Color badgeBgColor = isQuiz
                  ? const Color(0xFFEDE9FE)
                  : isVideo
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFE6FFFA);

              final Color badgeTextColor = isQuiz
                  ? const Color(0xFF5B21B6)
                  : isVideo
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFF0D9488);

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
                      // Vertical line indicator on the left (colored by theme)
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Icon in color background
                      Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            lessonIcon,
                            color: themeColor,
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
                                      color: badgeBgColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      itemTypeStr,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: badgeTextColor,
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
                            onPressed: () => widget.onEditLessonPressed(originalIndex),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            onPressed: () => widget.onDeleteLessonPressed(originalIndex),
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
            onPressed: widget.onAddLessonPressed,
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
        if (widget.lessons.isNotEmpty && totalPages > 1) ...[
          const SizedBox(height: 16),
          // Pagination control
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: _currentPage > 0 ? const Color(0xFF20B486) : const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 8),
              for (int i = 0; i < totalPages; i++) ...[
                GestureDetector(
                  onTap: () => setState(() => _currentPage = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _currentPage == i ? const Color(0xFF20B486) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: _currentPage == i ? null : Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: _currentPage == i ? Colors.white : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: _currentPage < totalPages - 1 ? const Color(0xFF20B486) : const Color(0xFF94A3B8),
                  size: 18,
                ),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
