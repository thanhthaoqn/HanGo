import 'package:flutter/material.dart';
import 'package:hango/utils/app_theme.dart';

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
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 14,
                color: AppTheme.emerald.withOpacity(0.8),
              ),
              const SizedBox(width: 6),
              const Text(
                'Suggested questions:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visible
                .take(3)
                .map((q) => _InteractivePromptChip(
                      label: q,
                      onTap: () => onTapQuestion(q),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _InteractivePromptChip extends StatefulWidget {
  const _InteractivePromptChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_InteractivePromptChip> createState() => _InteractivePromptChipState();
}

class _InteractivePromptChipState extends State<_InteractivePromptChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFFE6F7F4)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? AppTheme.emerald
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.emerald.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: _isHovered ? AppTheme.emerald : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                    color: _isHovered ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

