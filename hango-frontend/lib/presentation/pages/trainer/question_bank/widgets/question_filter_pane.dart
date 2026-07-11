import 'package:flutter/material.dart';

class QuestionFilterPane extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final String selectedGroupType;
  final ValueChanged<String> onGroupTypeChanged;

  const QuestionFilterPane({
    Key? key,
    required this.selectedType,
    required this.onTypeChanged,
    required this.selectedGroupType,
    required this.onGroupTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'FILTER BY STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...[
            {'value': 'ALL', 'label': 'All Questions', 'icon': Icons.list_alt_outlined},
            {'value': 'PRIVATE', 'label': 'Private', 'icon': Icons.lock_outline},
            {'value': 'PUBLIC', 'label': 'Public', 'icon': Icons.public_outlined},
          ].map((item) {
            final isSelected = selectedType == item['value'];
            return GestureDetector(
              onTap: () => onTypeChanged(item['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38C9A6).withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF38C9A6) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 16,
                      color: isSelected ? const Color(0xFF38C9A6) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF38C9A6) : const Color(0xFF475569),
                      ),
                    ),
                    if (isSelected) ...[
                      const Spacer(),
                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF38C9A6)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
