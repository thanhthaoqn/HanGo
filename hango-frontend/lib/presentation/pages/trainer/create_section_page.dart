import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../utils/toast_helper.dart';
import 'create_lesson_page.dart';

class CreateSectionPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final Future<void> Function(List<dynamic> updatedSections) onSectionsChanged;
  final ValueChanged<int>? onStepChanged;

  const CreateSectionPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.onSectionsChanged,
    this.onStepChanged,
  });

  @override
  State<CreateSectionPage> createState() => _CreateSectionPageState();
}

class _CreateSectionPageState extends State<CreateSectionPage> {
  late List<dynamic> _localSections;
  int? _editingIndex;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final Set<int> _expandedIndices = {};

  int _currentSectionPage = 0;
  static const int _sectionPageSize = 5;

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);
    // Expand the first section by default if any exist
    if (_localSections.isNotEmpty) {
      _expandedIndices.add(0);
    }
  }

  @override
  void didUpdateWidget(covariant CreateSectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sections != oldWidget.sections) {
      _localSections = List.from(widget.sections);
      final totalPages = (_localSections.length / _sectionPageSize).ceil();
      if (_currentSectionPage >= totalPages && totalPages > 0) {
        _currentSectionPage = totalPages - 1;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _notifyParent() async {
    await widget.onSectionsChanged(_localSections);
  }

  void _addSection() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, 'Please enter a section name');
      return;
    }

    setState(() {
      final newIndex = _localSections.length;
      _localSections.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': name,
        'description': desc,
        'orderIndex': newIndex + 1,
        'lessons': [],
      });
      // Expand the newly added section
      _expandedIndices.add(newIndex);
      _nameController.clear();
      _descController.clear();
    });
    _notifyParent();
    ToastHelper.showSuccess(context, 'Section added successfully');
  }

  void _updateSection() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    if (name.isEmpty) {
      ToastHelper.showError(context, 'Please enter a section name');
      return;
    }

    if (_editingIndex != null && _editingIndex! < _localSections.length) {
      setState(() {
        _localSections[_editingIndex!]['title'] = name;
        _localSections[_editingIndex!]['description'] = desc;
        _editingIndex = null;
        _nameController.clear();
        _descController.clear();
      });
      _notifyParent();
      ToastHelper.showSuccess(context, 'Section updated successfully');
    }
  }

  void _cancelEditing() {
    setState(() {
      _editingIndex = null;
      _nameController.clear();
      _descController.clear();
    });
  }

  void _deleteSection(int index) {
    setState(() {
      _localSections.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _nameController.clear();
        _descController.clear();
      } else if (_editingIndex != null && _editingIndex! > index) {
        _editingIndex = _editingIndex! - 1;
      }
      
      // Update expanded indices map
      final Set<int> updatedExpanded = {};
      for (final expandedIndex in _expandedIndices) {
        if (expandedIndex < index) {
          updatedExpanded.add(expandedIndex);
        } else if (expandedIndex > index) {
          updatedExpanded.add(expandedIndex - 1);
        }
      }
      _expandedIndices.clear();
      _expandedIndices.addAll(updatedExpanded);
    });
    _notifyParent();
    ToastHelper.showError(context, 'Section deleted');
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndices.contains(index)) {
        _expandedIndices.remove(index);
      } else {
        _expandedIndices.add(index);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFormCard(),
        const SizedBox(height: 24),
        _buildSectionsContainer(),
      ],
    );
  }

  Widget _buildFormCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFCCFBF1), // very light green border
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 28, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SECTION NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.2,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Section 1: Introduction to English Grammar',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: const Icon(Icons.subject, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF20B486), width: 1.5),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 20),
              const Text(
                'SECTION DESCRIPTION (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 1.2,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Briefly describe what students will learn in this chapter...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF20B486), width: 1.5),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editingIndex != null) ...[
                    OutlinedButton(
                      onPressed: _cancelEditing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _updateSection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20B486),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Update Section',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text(
                        'Add Section',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20B486),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 24,
          top: -12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF20B486),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _editingIndex != null ? 'EDIT SECTION' : 'NEW SECTION',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF20B486),
                letterSpacing: 1.0,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionsContainer() {
    Widget innerContent;
    if (_localSections.isEmpty) {
      innerContent = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        alignment: Alignment.center,
        child: const Text(
          'No sections created yet. Use the form above to add a section.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else {
      final totalPages = (_localSections.length / _sectionPageSize).ceil();
      final startIndex = _currentSectionPage * _sectionPageSize;
      final endIndex = (startIndex + _sectionPageSize < _localSections.length)
          ? startIndex + _sectionPageSize
          : _localSections.length;
      final paginatedSections = _localSections.sublist(startIndex, endIndex);

      innerContent = Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 16),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paginatedSections.length,
              itemBuilder: (context, index) {
                final originalIndex = startIndex + index;
                final section = paginatedSections[index];
                final lessons = section['lessons'] as List<dynamic>? ?? [];
                final isExpanded = _expandedIndices.contains(originalIndex);

                return Container(
                  margin: EdgeInsets.only(bottom: index == paginatedSections.length - 1 ? 0 : 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF5FF), // premium light blue bg
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Circle Index Badge
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD0E7FF),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${originalIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Title and count
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          section['title'] ?? 'Untitled Section',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF1E293B),
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${lessons.length} ${lessons.length == 1 ? "item" : "items"}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Color(0xFF64748B), size: 22),
                                    tooltip: 'Edit Section Info',
                                    onPressed: () {
                                      setState(() {
                                        _editingIndex = originalIndex;
                                        _nameController.text = section['title'] ?? '';
                                        _descController.text = section['description'] ?? '';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Action buttons
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                              tooltip: 'Edit Section',
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CreateLessonPage(
                                      courseId: widget.courseId,
                                      courseTitle: widget.courseTitle,
                                      trainerName: widget.trainerName,
                                      trainerInitials: widget.trainerInitials,
                                      sections: _localSections,
                                      selectedSectionIndex: originalIndex,
                                      onSectionsChanged: (updatedSections) async {
                                        setState(() {
                                          _localSections = updatedSections;
                                        });
                                        await _notifyParent();
                                      },
                                    ),
                                  ),
                                );
                                if (result == 'goToIntroduction' && widget.onStepChanged != null) {
                                  widget.onStepChanged!(1);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                              tooltip: 'Delete Section',
                              onPressed: () => _deleteSection(originalIndex),
                            ),
                            IconButton(
                              icon: Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: const Color(0xFF64748B),
                                size: 22,
                              ),
                              tooltip: isExpanded ? 'Collapse' : 'Expand',
                              onPressed: () => _toggleExpanded(originalIndex),
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded) ...[
                        const Divider(color: Color(0xFFD0E7FF), height: 1),
                        Container(
                          color: Colors.white.withAlpha(102),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (section['description'] != null && section['description'].toString().trim().isNotEmpty)
                                Text(
                                  section['description'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                    fontFamily: 'Outfit',
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                const Text(
                                  'No description provided for this section.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF94A3B8),
                                    fontFamily: 'Outfit',
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: _currentSectionPage > 0 ? const Color(0xFF20B486) : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: _currentSectionPage > 0
                        ? () => setState(() => _currentSectionPage--)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  for (int i = 0; i < totalPages; i++) ...[
                    GestureDetector(
                      onTap: () => setState(() => _currentSectionPage = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _currentSectionPage == i ? const Color(0xFF20B486) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: _currentSectionPage == i ? null : Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: _currentSectionPage == i ? Colors.white : const Color(0xFF475569),
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
                      color: _currentSectionPage < totalPages - 1 ? const Color(0xFF20B486) : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: _currentSectionPage < totalPages - 1
                        ? () => setState(() => _currentSectionPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: DashedRoundedBorderPainter(
            color: const Color(0xFFCBD5E1),
            borderRadius: 12,
          ),
          child: innerContent,
        ),
        Positioned(
          left: 24,
          top: -12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF20B486),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: const Text(
              'SECTION LIST',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF20B486),
                letterSpacing: 1.0,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = dashWidth;
        if (distance + len > metric.length) {
          dashedPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashedPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
