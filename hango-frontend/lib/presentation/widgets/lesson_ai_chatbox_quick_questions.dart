import 'package:flutter/material.dart';

class QuickQuestionsRow extends StatelessWidget {
  const QuickQuestionsRow({
    super.key,
    required this.questions,
    required this.onTapQuestion,
  });

  final List<String> questions;
  final ValueChanged<String> onTapQuestion;

  @override
  Widget build(BuildContext context) {
    final visible = questions.where((e) => e.trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: visible
            .take(3)
            .map(
              (q) => ActionChip(
                label: Text(q),
                onPressed: () => onTapQuestion(q),
                backgroundColor: const Color(0xFFEAF3EE),
              ),
            )
            .toList(),
      ),
    );
  }
}
