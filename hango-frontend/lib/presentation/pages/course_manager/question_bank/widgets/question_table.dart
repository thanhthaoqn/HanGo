import 'package:flutter/material.dart';
import '../models/course_manager_question.dart';

class QuestionTable extends StatelessWidget {
  final List<CourseManagerQuestion> questions;
  final bool isLoading;
  final int currentPage;
  final int totalRecords;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<CourseManagerQuestion> onViewPressed;
  final ValueChanged<CourseManagerQuestion> onEditPressed;
  final Function(CourseManagerQuestion, bool) onStatusToggled;
  final bool isCourseManager;

  const QuestionTable({
    Key? key,
    required this.questions,
    required this.isLoading,
    required this.currentPage,
    required this.totalRecords,
    required this.pageSize,
    required this.onPageChanged,
    required this.onViewPressed,
    required this.onEditPressed,
    required this.onStatusToggled,
    this.isCourseManager = false,
  }) : super(key: key);

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF20B486)),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.question_answer_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No questions found.',
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final int startRecord = (currentPage - 1) * pageSize + 1;
    final int endRecord = (startRecord + questions.length - 1).clamp(0, totalRecords);
    final int totalPages = (totalRecords / pageSize).ceil();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text(
                    'NO.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Question',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date\nCreated',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Last\nUpdated',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                if (!isCourseManager)
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: questions.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final q = questions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // NO.
                    SizedBox(
                      width: 60,
                      child: Text(
                        q.displayNo ?? q.id.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    // Question text
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q.questionText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (q.categoryName.isNotEmpty && q.categoryName != 'Chưa phân loại')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    q.categoryName,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              if (q.skillName != null && q.skillName!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    q.skillName!,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              if (q.groupTypeName != null && q.groupTypeName!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCE7F3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    q.groupTypeName!,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFBE185D), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              if (!q.isGroup && q.difficultyName.isNotEmpty && q.difficultyName != 'null')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(q.difficultyName).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    q.difficultyName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _getDifficultyColor(q.difficultyName),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Date Created
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(q.createdAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(q.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Last Updated
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatTime(q.updatedAt),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(q.updatedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status (Toggle)
                    if (!isCourseManager)
                      Expanded(
                        flex: 2,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: q.status == 'PUBLIC',
                                activeColor: const Color(0xFF20B486),
                                onChanged: (val) {
                                  onStatusToggled(q, val);
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                q.status == 'PUBLIC' ? 'Public' : 'Private',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: q.status == 'PUBLIC' ? const Color(0xFF20B486) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Actions
                    SizedBox(
                      width: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            color: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => onViewPressed(q),
                            tooltip: 'View Question',
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => onEditPressed(q),
                            tooltip: 'Edit Question',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // Pagination and Footer
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startRecord to $endRecord of $totalRecords records',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                Row(
                  children: [
                    // Back button
                    _buildPageButton(
                      icon: Icons.chevron_left,
                      onTap: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                    ),
                    const SizedBox(width: 4),
                    // Number buttons
                    ..._getPageNumbers(currentPage, totalPages).map((p) {
                      if (p == null) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        );
                      }
                      final isSelected = p == currentPage;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: _buildPageNumberButton(
                          pageNumber: p,
                          isSelected: isSelected,
                          onTap: () => onPageChanged(p),
                        ),
                      );
                    }).toList(),
                    const SizedBox(width: 4),
                    // Next button
                    _buildPageButton(
                      icon: Icons.chevron_right,
                      onTap: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return const Color(0xFF10B981);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'HARD':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
          color: disabled ? const Color(0xFFF8FAFC) : Colors.white,
        ),
        child: Icon(
          icon,
          size: 16,
          color: disabled ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPageNumberButton({
    required int pageNumber,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF20B486) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF20B486) : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          pageNumber.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  List<int?> _getPageNumbers(int currentPage, int totalPages) {
    if (totalPages <= 7) {
      return List.generate(totalPages, (index) => index + 1);
    }
    
    if (currentPage <= 4) {
      return [1, 2, 3, 4, 5, null, totalPages];
    }
    
    if (currentPage >= totalPages - 3) {
      return [1, null, totalPages - 4, totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
    }
    
    return [1, null, currentPage - 1, currentPage, currentPage + 1, null, totalPages];
  }
}
