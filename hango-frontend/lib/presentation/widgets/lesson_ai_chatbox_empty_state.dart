import 'package:flutter/material.dart';

import 'lesson_ai_chatbox_quick_questions.dart';

/// Widget hiển thị trạng thái rỗng của chatbox + 3 câu hỏi gợi ý.
class LessonAiChatboxEmptyState extends StatelessWidget {
  const LessonAiChatboxEmptyState({
    super.key,
    required this.questions,
    required this.onTapQuestion,
    this.title,
  });

  final List<String> questions;
  final void Function(String question) onTapQuestion;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final effectiveTitle =
        title ?? 'Hãy chọn một câu hỏi gợi ý để bắt đầu học cùng AI.';

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              effectiveTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Hiển thị 3 câu dạng quick questions.
            QuickQuestionsRow(
              questions: questions,
              onTapQuestion: onTapQuestion,
            ),
          ],
        ),
      ),
    );
  }
}
