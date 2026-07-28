import 'package:flutter/material.dart';
import 'package:hango/utils/app_theme.dart';
import 'lesson_ai_chatbox_quick_questions.dart';
/// Widget displaying empty state of chatbox + 3 suggested questions with UI/UX Pro Max.
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
        title ?? 'Select a suggested prompt below or type your own question to start learning with AI.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing AI Hero Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF28B79B), Color(0xFF0D9488)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.emerald.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'HanGo AI Assistant',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                effectiveTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Quick Questions
            Align(
              alignment: Alignment.centerLeft,
              child: QuickQuestionsRow(
                questions: questions,
                onTapQuestion: onTapQuestion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

