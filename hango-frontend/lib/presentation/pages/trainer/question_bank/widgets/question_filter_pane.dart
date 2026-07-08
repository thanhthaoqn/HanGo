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
            color: Colors.black.withOpacity(0.02),
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
            'SELECT TYPE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: ['QUIZ', 'EXAM'].map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onTypeChanged(value);
                  }
                },
              ),
            ),
          ),
          if (selectedType == 'EXAM') ...[
            const SizedBox(height: 24),
            const Text(
              'SELECT GROUP TYPE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedGroupType,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    'Choose Group Type',
                    'SHORT_CLOZE_ANNOUNCEMENT',
                    'SHORT_CLOZE_LEAFLET',
                    'REORDER_CONVERSATION',
                    'REORDER_TEXT',
                    'LONG_CLOZE',
                    'READING_COMPREHENSION_1',
                    'READING_COMPREHENSION_2'
                  ].map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onGroupTypeChanged(value);
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
