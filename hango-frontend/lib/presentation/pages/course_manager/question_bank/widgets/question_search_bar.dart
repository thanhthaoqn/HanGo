import 'package:flutter/material.dart';

class QuestionSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final String sortBy;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onCreatePressed;
  final VoidCallback onImportPressed;
  final VoidCallback onRefreshPressed;
  final bool isCourseManager;
  final List<Map<String, dynamic>>? skills;
  final List<Map<String, dynamic>>? groupTypes;
  final List<Map<String, dynamic>>? difficulties;
  final int? selectedSkillId;
  final ValueChanged<int?>? onSkillChanged;
  final int? selectedGroupTypeId;
  final ValueChanged<int?>? onGroupTypeChanged;
  final int? selectedDifficultyId;
  final ValueChanged<int?>? onDifficultyChanged;

  const QuestionSearchBar({
    Key? key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedType,
    required this.onTypeChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.onCreatePressed,
    required this.onImportPressed,
    required this.onRefreshPressed,
    this.isCourseManager = false,
    this.skills,
    this.groupTypes,
    this.difficulties,
    this.selectedSkillId,
    this.onSkillChanged,
    this.selectedGroupTypeId,
    this.onGroupTypeChanged,
    this.selectedDifficultyId,
    this.onDifficultyChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isCourseManager) {
      return Row(
        children: [
          // Search box
          Expanded(
            flex: 3,
            child: _buildSearchBox(),
          ),
          const SizedBox(width: 12),
          // Skill Type filter
          if (skills != null) Expanded(flex: 2, child: _buildFilterDropdown('Skill Type', skills!, selectedSkillId, onSkillChanged)),
          if (skills != null) const SizedBox(width: 12),
          // Group Type filter
          if (groupTypes != null) Expanded(flex: 2, child: _buildFilterDropdown('Group Type', groupTypes!, selectedGroupTypeId, onGroupTypeChanged)),
          if (groupTypes != null) const SizedBox(width: 12),
          // Difficulty filter
          if (difficulties != null) Expanded(flex: 2, child: _buildFilterDropdown('Difficulty', difficulties!, selectedDifficultyId, onDifficultyChanged)),
          if (difficulties != null) const SizedBox(width: 12),
          // Sort Dropdown
          _buildSortDropdown(),
          const SizedBox(width: 12),
          // Refresh Button
          _buildRefreshButton(),
        ],
      );
    }

    return Row(
      children: [
        // Status Filter Dropdown
        _buildStatusDropdown(),
        const SizedBox(width: 12),
        // Search box
        Expanded(
          flex: 4,
          child: _buildSearchBox(),
        ),
        const SizedBox(width: 12),
        // Create New Question Button
        _buildCreateButton(),
        const SizedBox(width: 12),
        // Import from Excel Button
        _buildImportButton(),
        const SizedBox(width: 12),
        // Sort Dropdown
        _buildSortDropdown(),
        const SizedBox(width: 12),
        // Refresh Button
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Color(0xFF64748B), size: 18),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedType,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('Public', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
                DropdownMenuItem(value: 'PRIVATE', child: Text('Private', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
              ],
              onChanged: (val) {
                if (val != null) onTypeChanged(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
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
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton.icon(
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
    );
  }

  Widget _buildImportButton() {
    return OutlinedButton.icon(
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
    );
  }

  Widget _buildSortDropdown() {
    return Container(
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
    );
  }

  Widget _buildRefreshButton() {
    return InkWell(
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
    );
  }

  Widget _buildFilterDropdown(String hint, List<Map<String, dynamic>> items, int? value, ValueChanged<int?>? onChanged) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          hint: Text(hint, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
          dropdownColor: Colors.white,
          isExpanded: true,
          selectedItemBuilder: (BuildContext context) {
            return [
              DropdownMenuItem<int>(
                value: null,
                child: Text('All $hint', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
              ),
              ...items.map((item) {
                return DropdownMenuItem<int>(
                  value: item['id'] as int,
                  child: Text('$hint: ${item['paramValue'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
            ].map((e) => Container(alignment: Alignment.centerLeft, child: e.child)).toList();
          },
          items: [
            DropdownMenuItem<int>(
              value: null,
              child: Text('All $hint', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            ),
            ...items.map((item) {
              return DropdownMenuItem<int>(
                value: item['id'] as int,
                child: Text(item['paramValue'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              );
            }).toList(),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
