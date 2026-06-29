import 'package:flutter/material.dart';

class QuestionSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String sortBy;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onCreatePressed;
  final VoidCallback onImportPressed;
  final VoidCallback onRefreshPressed;

  const QuestionSearchBar({
    Key? key,
    required this.searchController,
    required this.onSearchChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.onCreatePressed,
    required this.onImportPressed,
    required this.onRefreshPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search box
        Expanded(
          flex: 4,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search questions by code, title.....',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Create New Question Button
        ElevatedButton.icon(
          onPressed: onCreatePressed,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
          label: const Text(
            'Create\nNew Question',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(130, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(width: 12),
        // Import from Excel Button
        OutlinedButton.icon(
          onPressed: onImportPressed,
          icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF1E293B), size: 18),
          label: const Text(
            'Import\nfrom Excel',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            minimumSize: const Size(110, 48),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Sort Dropdown/Button
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sort, color: Color(0xFF64748B), size: 18),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: sortBy == 'NEWEST' ? 'Newest' : 'Oldest',
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
                  dropdownColor: Colors.white,
                  items: ['Newest', 'Oldest'].map((String val) {
                    return DropdownMenuItem<String>(
                      value: val,
                      child: Text(
                        'Sort by:\n$val',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          height: 1.1,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      onSortChanged(val == 'Newest' ? 'NEWEST' : 'OLDEST');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Refresh Button
        InkWell(
          onTap: onRefreshPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 20),
          ),
        ),
      ],
    );
  }
}
