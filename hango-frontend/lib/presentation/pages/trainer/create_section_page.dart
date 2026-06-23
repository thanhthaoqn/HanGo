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

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);
  }

  @override
  void didUpdateWidget(covariant CreateSectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sections != oldWidget.sections) {
      _localSections = List.from(widget.sections);
    }
  }

  void _notifyParent() {
    widget.onSectionsChanged(_localSections);
  }

  void _showAddSectionDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Create New Section',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Section Title *',
                  hintText: 'e.g. Introduction to Grammar',
                  labelStyle: TextStyle(fontFamily: 'Outfit'),
                  hintStyle: TextStyle(fontFamily: 'Outfit'),
                ),
                autofocus: true,
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
                    _localSections.add({
                      'id': DateTime.now().millisecondsSinceEpoch,
                      'title': text,
                      'orderIndex': _localSections.length + 1,
                      'lessons': [],
                    });
                  });
                  _notifyParent();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20B486),
              ),
              child: const Text('Create', style: TextStyle(color: Colors.white, fontFamily: 'Outfit')),
            ),
          ],
        );
      },
    );
  }

  void _showEditSectionDialog(int index) {
    final titleController = TextEditingController(text: _localSections[index]['title']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Edit Section Title',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Section Title *',
              labelStyle: TextStyle(fontFamily: 'Outfit'),
            ),
            autofocus: true,
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
                    _localSections[index]['title'] = text;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Course Content',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_localSections.length} ${_localSections.length == 1 ? "Section" : "Sections"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddSectionDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'New Section',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B486),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_localSections.isEmpty)
            _buildEmptyCurriculumState()
          else
            _buildSectionsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyCurriculumState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF2F5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Stack
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6FFFA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: Color(0xFF20B486),
                  size: 32,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF20B486),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'No chapters yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start building your course by creating your first instructional chapter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddSectionDialog,
            icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Colors.white),
            label: const Text(
              'Create Section',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Outfit',
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
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
        final lessons = section['lessons'] as List<dynamic>? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: ExpansionTile(
            key: PageStorageKey<int>(section['id'] ?? index),
            initiallyExpanded: true,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE6FFFA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open,
                color: Color(0xFF20B486),
                size: 20,
              ),
            ),
            title: Text(
              'Section ${index + 1}: ${section['title']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
                fontFamily: 'Outfit',
              ),
            ),
            subtitle: Text(
              '${lessons.length} ${lessons.length == 1 ? "lesson" : "lessons"}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF20B486), size: 20),
                  tooltip: 'Add Lesson',
                  onPressed: () => _showAddLessonDialog(index),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 18),
                  onPressed: () => _showEditSectionDialog(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () {
                    setState(() {
                      _localSections.removeAt(index);
                    });
                    _notifyParent();
                  },
                ),
              ],
            ),
            children: [
              if (lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No lessons in this section yet. Click the + icon to add a lesson.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                      fontFamily: 'Outfit',
                    ),
                  ),
                )
              else
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
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            ],
          ),
        );
      },
    );
  }
}
