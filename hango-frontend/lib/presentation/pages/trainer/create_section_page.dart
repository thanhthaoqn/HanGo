import 'dart:ui';
import 'package:flutter/material.dart';

class CreateSectionPage extends StatefulWidget {
  final List<dynamic> sections;
  final ValueChanged<List<dynamic>> onSectionsChanged;

  const CreateSectionPage({
    super.key,
    required this.sections,
    required this.onSectionsChanged,
  });

  @override
  State<CreateSectionPage> createState() => _CreateSectionPageState();
}

class _CreateSectionPageState extends State<CreateSectionPage> {
  late List<dynamic> _localSections;
  final _sectionNameController = TextEditingController();
  final _sectionDescController = TextEditingController();
  int? _editingSectionIndex; // null if creating a new section
  final Map<int, bool> _expandedSections = {}; // track expanded/collapsed state

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);
    // Expand all sections by default
    for (var i = 0; i < _localSections.length; i++) {
      final id = _localSections[i]['id'] as int? ?? i;
      _expandedSections[id] = true;
    }
  }

  @override
  void didUpdateWidget(covariant CreateSectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sections != oldWidget.sections) {
      _localSections = List.from(widget.sections);
      for (var i = 0; i < _localSections.length; i++) {
        final id = _localSections[i]['id'] as int? ?? i;
        if (!_expandedSections.containsKey(id)) {
          _expandedSections[id] = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _sectionNameController.dispose();
    _sectionDescController.dispose();
    super.dispose();
  }

  void _notifyParent() {
    widget.onSectionsChanged(_localSections);
  }

  void _resetForm() {
    setState(() {
      _sectionNameController.clear();
      _sectionDescController.clear();
      _editingSectionIndex = null;
    });
  }

  void _saveSectionForm() {
    final title = _sectionNameController.text.trim();
    final description = _sectionDescController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a section name')),
      );
      return;
    }

    setState(() {
      if (_editingSectionIndex != null) {
        // Edit existing
        final index = _editingSectionIndex!;
        _localSections[index]['title'] = title;
        _localSections[index]['description'] = description;
      } else {
        // Add new
        final newSection = {
          'id': DateTime.now().millisecondsSinceEpoch,
          'title': title,
          'description': description,
          'orderIndex': _localSections.length + 1,
          'lessons': [],
        };
        _localSections.add(newSection);
        _expandedSections[newSection['id'] as int] = true; // Expand by default
      }
      _resetForm();
    });
    _notifyParent();
  }

  void _confirmDeleteSection(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Section', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to delete "${_localSections[index]['title']}"? All lessons inside this section will be permanently deleted.',
            style: const TextStyle(fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Outfit')),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _localSections.removeAt(index);
                  if (_editingSectionIndex == index) {
                    _resetForm();
                  } else if (_editingSectionIndex != null && _editingSectionIndex! > index) {
                    _editingSectionIndex = _editingSectionIndex! - 1;
                  }
                });
                _notifyParent();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
            ),
          ],
        );
      },
    );
  }

  void _showAddLessonDialog(int sectionIndex) {
    final titleController = TextEditingController();
    String selectedType = 'video';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Add Lesson',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Title *',
                      hintText: 'e.g. Nouns and Pronouns',
                      labelStyle: TextStyle(fontFamily: 'Outfit'),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Type',
                      labelStyle: TextStyle(fontFamily: 'Outfit'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Video Lecture', style: TextStyle(fontFamily: 'Outfit'))),
                      DropdownMenuItem(value: 'text', child: Text('Document/Reading', style: TextStyle(fontFamily: 'Outfit'))),
                      DropdownMenuItem(value: 'quiz', child: Text('Quiz/Assessment', style: TextStyle(fontFamily: 'Outfit'))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Outfit')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = titleController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        final lessons = _localSections[sectionIndex]['lessons'] as List<dynamic>? ?? [];
                        lessons.add({
                          'id': DateTime.now().millisecondsSinceEpoch,
                          'title': text,
                          'itemType': selectedType,
                          'displayOrder': lessons.length + 1,
                        });
                        _localSections[sectionIndex]['lessons'] = lessons;
                      });
                      _notifyParent();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                  ),
                  child: const Text('Add', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditLessonDialog(int sectionIndex, int lessonIndex) {
    final lesson = _localSections[sectionIndex]['lessons'][lessonIndex];
    final titleController = TextEditingController(text: lesson['title']);
    String selectedType = lesson['itemType'] ?? 'video';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Lesson',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Title *',
                      labelStyle: TextStyle(fontFamily: 'Outfit'),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Type',
                      labelStyle: TextStyle(fontFamily: 'Outfit'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Video Lecture', style: TextStyle(fontFamily: 'Outfit'))),
                      DropdownMenuItem(value: 'text', child: Text('Document/Reading', style: TextStyle(fontFamily: 'Outfit'))),
                      DropdownMenuItem(value: 'quiz', child: Text('Quiz/Assessment', style: TextStyle(fontFamily: 'Outfit'))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontFamily: 'Outfit')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = titleController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _localSections[sectionIndex]['lessons'][lessonIndex]['title'] = text;
                        _localSections[sectionIndex]['lessons'][lessonIndex]['itemType'] = selectedType;
                      });
                      _notifyParent();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionFormCard() {
    final isEditing = _editingSectionIndex != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2F9F3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF20B486).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Badge on the top border
          Positioned(
            top: -36,
            left: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF20B486).withOpacity(0.2)),
              ),
              child: Text(
                isEditing ? 'EDIT SECTION ${_editingSectionIndex! + 1}' : 'NEW SECTION',
                style: const TextStyle(
                  color: Color(0xFF20B486),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Section Name label
              const Text(
                'SECTION NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4B5563),
                  fontFamily: 'Outfit',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Section Name Field
              TextFormField(
                controller: _sectionNameController,
                decoration: InputDecoration(
                  hintText: 'Section 1: Introduction to English Grammar',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: const Icon(Icons.notes, color: Color(0xFFCBD5E1), size: 20),
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
                    borderSide: const BorderSide(color: Color(0xFF20B486)),
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              // Section Description label
              const Text(
                'SECTION DESCRIPTION (OPTIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4B5563),
                  fontFamily: 'Outfit',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Section Description Field
              TextFormField(
                controller: _sectionDescController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Briefly describe what students will learn in this chapter...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                    fontStyle: FontStyle.italic,
                  ),
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
                    borderSide: const BorderSide(color: Color(0xFF20B486)),
                  ),
                ),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              // Form actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isEditing) ...[
                    TextButton(
                      onPressed: _resetForm,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton(
                    onPressed: _saveSectionForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF20B486),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Add Section',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _localSections.length,
      itemBuilder: (context, index) {
        final section = _localSections[index];
        final sectionId = section['id'] as int? ?? index;
        final lessons = section['lessons'] as List<dynamic>? ?? [];
        final isExpanded = _expandedSections[sectionId] ?? true;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F9F3).withOpacity(0.3),
                  borderRadius: isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : BorderRadius.circular(12),
                  border: Border(
                    bottom: BorderSide(
                      color: isExpanded ? const Color(0xFFEFF2F5) : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Badge Number
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2F9F3),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF20B486),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and Items Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Section ${index + 1}: ${section['title']}',
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
                    // Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFFE2A93E), size: 20),
                          tooltip: 'Edit Section',
                          onPressed: () {
                            setState(() {
                              _editingSectionIndex = index;
                              _sectionNameController.text = section['title'] ?? '';
                              _sectionDescController.text = section['description'] ?? '';
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Delete Section',
                          onPressed: () => _confirmDeleteSection(index),
                        ),
                        IconButton(
                          icon: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: const Color(0xFF64748B),
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _expandedSections[sectionId] = !isExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Section Lessons List (when expanded)
              if (isExpanded)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (lessons.isEmpty)
                        // Dashed Border box for 0 items
                        CustomPaint(
                          painter: DashedBorderPainter(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: 8,
                          ),
                          child: Container(
                            height: 100,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'No lessons in this section yet.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _showAddLessonDialog(index),
                                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
                                  label: const Text(
                                    'Add Lesson',
                                    style: TextStyle(
                                      color: Color(0xFF20B486),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Lessons List
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: lessons.length,
                          itemBuilder: (context, lessonIndex) {
                            final lesson = lessons[lessonIndex];
                            IconData lessonIcon = Icons.play_circle_outline;
                            if (lesson['itemType'] == 'quiz' || lesson['itemType'] == 'practice') {
                              lessonIcon = Icons.assignment_outlined;
                            } else if (lesson['itemType'] == 'document' || lesson['itemType'] == 'text') {
                              lessonIcon = Icons.description_outlined;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFEFF2F5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(lessonIcon, color: const Color(0xFF64748B), size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      lesson['title'] ?? 'Untitled Lesson',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1E293B),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 16),
                                    onPressed: () => _showEditLessonDialog(index, lessonIndex),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        (section['lessons'] as List<dynamic>).removeAt(lessonIndex);
                                      });
                                      _notifyParent();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showAddLessonDialog(index),
                            icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
                            label: const Text(
                              'Add Lesson',
                              style: TextStyle(
                                color: Color(0xFF20B486),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.01),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionFormCard(),
          const SizedBox(height: 32),
          const Text(
            'Course Curriculum',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          if (_localSections.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEFF2F5)),
              ),
              child: const Text(
                'No sections added yet. Use the form above to create your first section.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontFamily: 'Outfit',
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            _buildSectionsList(),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
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

    final double w = size.width;
    final double h = size.height;

    // Draw dashed path for rounded rect
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    final Path dashedPath = Path();
    double distance = 0.0;
    for (final PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashedPath.addPath(
          measurePath.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
