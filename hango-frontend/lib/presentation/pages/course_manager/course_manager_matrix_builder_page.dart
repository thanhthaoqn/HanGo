import 'package:flutter/material.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../widgets/course_manager_sidebar.dart';

enum MatrixMode { create, view, edit }

class CourseManagerMatrixBuilderPage extends StatefulWidget {
  final CourseManagerApi api;
  final VoidCallback onSaved;
  final MatrixMode mode;
  final Map<String, dynamic>? initialData;

  const CourseManagerMatrixBuilderPage({
    super.key,
    required this.api,
    required this.onSaved,
    this.mode = MatrixMode.create,
    this.initialData,
  });

  @override
  State<CourseManagerMatrixBuilderPage> createState() => _CourseManagerMatrixBuilderPageState();
}

class _CourseManagerMatrixBuilderPageState extends State<CourseManagerMatrixBuilderPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final List<Map<String, dynamic>> _rules = [];
  bool _isSaving = false;
  bool _isLoadingData = true;

  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _difficulties = [];
  List<Map<String, dynamic>> _groupTypes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final skillTypeFuture = widget.api.getSystemParameters('SKILL_TYPE');
      final skillFuture = widget.api.getSystemParameters('SKILL');
      final groupTypeFuture = widget.api.getSystemParameters('GROUP_TYPE');
      final diffFuture = widget.api.getSystemParameters('DIFFICULTY');
      
      final results = await Future.wait([skillTypeFuture, skillFuture, groupTypeFuture, diffFuture]);
      
      final skillsCombined = [...results[0], ...results[1]];
      final uniqueSkills = <int, Map<String, dynamic>>{};
      for (var s in skillsCombined) {
        uniqueSkills[s['id'] as int] = s;
      }
      
      if (mounted) {
        setState(() {
          _skills = uniqueSkills.values.map((s) => {
            'id': s['id'], 'name': s['paramValue'] ?? s['paramKey']
          }).toList();
          
          _groupTypes = results[2].map((s) => {
            'id': s['id'], 'name': s['paramValue'] ?? s['paramKey']
          }).toList();
          
          _difficulties = results[3].map((s) => {
            'id': s['id'], 'name': s['paramValue'] ?? s['paramKey']
          }).toList();
          
          _isLoadingData = false;

          if (widget.initialData != null) {
            _titleController.text = widget.initialData!['title'] ?? '';
            _descController.text = widget.initialData!['description'] ?? '';
            final details = widget.initialData!['details'] as List? ?? [];
            _rules.clear();

            // Track pending group building state
            int? currentGroupTypeId;
            List<Map<String, dynamic>>? currentGroupSubQs;

            void flushGroup() {
              if (currentGroupTypeId != null && currentGroupSubQs != null) {
                _rules.add({
                  'type': 'group',
                  'groupTypeId': currentGroupTypeId,
                  'subQuestions': currentGroupSubQs,
                });
                currentGroupTypeId = null;
                currentGroupSubQs = null;
              }
            }

            for (var d in details) {
              int qty = d['quantity'] ?? 1;
              if (d['groupTypeId'] == null) {
                // Flush any pending group before adding singles
                flushGroup();
                for (int i = 0; i < qty; i++) {
                  _rules.add({
                    'type': 'single',
                    'skillId': d['skillParamId'],
                    'diffId': d['difficultyParamId'],
                    'groupTypeId': null,
                  });
                }
              } else {
                int groupId = d['groupTypeId'];
                // If a different group starts, flush current group first
                if (currentGroupTypeId != null && currentGroupTypeId != groupId) {
                  flushGroup();
                }
                if (currentGroupTypeId == null) {
                  currentGroupTypeId = groupId;
                  currentGroupSubQs = [];
                }
                for (int i = 0; i < qty; i++) {
                  currentGroupSubQs!.add({
                    'skillId': d['skillParamId'],
                    'diffId': d['difficultyParamId'],
                  });
                }
              }
            }
            flushGroup();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ToastHelper.showError(context, 'System error, please try again later.');
      }
    }
  }

  void _addRule(String type) {
    setState(() {
      if (type == 'single') {
        _rules.add({
          'type': type,
          'skillId': null,
          'groupTypeId': null,
          'diffId': null,
        });
      } else {
        _rules.add({
          'type': type,
          'groupTypeId': null,
          'subQuestions': [
            <String, dynamic>{'skillId': null, 'diffId': null}
          ],
        });
      }
    });
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _addSubQuestion(int ruleIndex) {
    setState(() {
      (_rules[ruleIndex]['subQuestions'] as List).add(<String, dynamic>{'skillId': null, 'diffId': null});
    });
  }

  void _removeSubQuestion(int ruleIndex, int subIndex) {
    setState(() {
      (_rules[ruleIndex]['subQuestions'] as List).removeAt(subIndex);
    });
  }

  int get _totalQuestions {
    return _rules.fold(0, (sum, rule) {
      if (rule['type'] == 'single') return sum + 1;
      return sum + (rule['subQuestions'] as List).length;
    });
  }

  String _getQuestionLabel(int index) {
    int startIndex = 1;
    for (int i = 0; i < index; i++) {
      if (_rules[i]['type'] == 'single') {
        startIndex += 1;
      } else {
        startIndex += (_rules[i]['subQuestions'] as List).length;
      }
    }
    int qty = _rules[index]['type'] == 'single' ? 1 : (_rules[index]['subQuestions'] as List).length;
    if (qty <= 1) {
      return 'Question $startIndex';
    } else {
      return 'Questions $startIndex - ${startIndex + qty - 1}';
    }
  }

  String? _titleError;

  bool _validate() {
    bool isValid = true;
    setState(() {
      _titleError = null;
      if (_titleController.text.trim().isEmpty) {
        _titleError = 'Title cannot be empty';
        isValid = false;
      }
      
      for (var r in _rules) {
        r['groupTypeError'] = null;
        r['skillError'] = null;
        r['diffError'] = null;
        
        if (r['type'] == 'single') {
          if (r['skillId'] == null) {
            r['skillError'] = 'Please select a Skill Type';
            isValid = false;
          }
          if (r['diffId'] == null) {
            r['diffError'] = 'Please select a Difficulty';
            isValid = false;
          }
        } else {
          if (r['groupTypeId'] == null) {
            r['groupTypeError'] = 'Please select a Group Type';
            isValid = false;
          }
          final subQ = r['subQuestions'] as List;
          for (var sq in subQ) {
            sq['skillError'] = null;
            sq['diffError'] = null;
            if (sq['skillId'] == null) {
              sq['skillError'] = 'Please select a Skill Type';
              isValid = false;
            }
            if (sq['diffId'] == null) {
              sq['diffError'] = 'Please select a Difficulty';
              isValid = false;
            }
          }
        }
      }
    });
    return isValid && _rules.isNotEmpty;
  }

  Future<void> _saveMatrix() async {
    if (!_validate()) return;

    setState(() => _isSaving = true);

    try {
      // Build ordered flat list preserving rule order,
      // grouping only CONTIGUOUS identical configs to minimize DB rows
      final orderedDetails = <Map<String, dynamic>>[];

      Map<String, dynamic>? lastDetail;

      void pushDetail(Map<String, dynamic> d) {
        final key = '${d['skillParamId']}_${d['difficultyParamId']}_${d['groupTypeId']}';
        if (lastDetail != null) {
          final lastKey = '${lastDetail!['skillParamId']}_${lastDetail!['difficultyParamId']}_${lastDetail!['groupTypeId']}';
          if (lastKey == key) {
            lastDetail!['quantity'] = (lastDetail!['quantity'] as int) + 1;
            return;
          }
        }
        lastDetail = {
          'skillParamId': d['skillParamId'],
          'difficultyParamId': d['difficultyParamId'],
          'groupTypeId': d['groupTypeId'],
          'quantity': 1,
        };
        orderedDetails.add(lastDetail!);
      }

      for (var r in _rules) {
        if (r['type'] == 'single') {
          pushDetail({
            'skillParamId': r['skillId'],
            'difficultyParamId': r['diffId'],
            'groupTypeId': null,
          });
        } else {
          for (var sq in (r['subQuestions'] as List)) {
            pushDetail({
              'skillParamId': sq['skillId'],
              'difficultyParamId': sq['diffId'],
              'groupTypeId': r['groupTypeId'],
            });
          }
        }
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'details': orderedDetails,
      };

      if (widget.mode == MatrixMode.edit && widget.initialData != null) {
        await widget.api.updateExamMatrix(widget.initialData!['id'], data);
        if (mounted) ToastHelper.showSuccess(context, 'Matrix updated successfully!');
      } else {
        await widget.api.createExamMatrix(data);
        if (mounted) ToastHelper.showSuccess(context, 'Matrix created successfully!');
      }
      
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'System error, please try again later.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: '',),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'matrix')) : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'matrix')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 750),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildGeneralInfoCard(),
                                  const SizedBox(height: 32),
                                  _buildRulesHeader(),
                                  const SizedBox(height: 16),
                                  if (_isLoadingData)
                                    const Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Center(child: CircularProgressIndicator(color: Color(0xFF20B486))),
                                    )
                                  else if (_rules.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'No rules added yet.\nAdd single questions or passages to get started.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Reorderable list as a proper sliver — no shrinkWrap, no lag
                      if (!_isLoadingData && _rules.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          sliver: SliverReorderableList(
                            itemCount: _rules.length,
                            onReorder: widget.mode == MatrixMode.view
                                ? (_, __) {}
                                : (int oldIndex, int newIndex) {
                                    setState(() {
                                      if (newIndex > oldIndex) newIndex--;
                                      final item = _rules.removeAt(oldIndex);
                                      _rules.insert(newIndex, item);
                                    });
                                  },
                            proxyDecorator: (child, index, animation) => Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                              child: child,
                            ),
                            itemBuilder: (context, index) {
                              return Center(
                                key: ValueKey('rule_$index'),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 750),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildRuleCard(index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 750),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!_isLoadingData) _buildAddButtons(),
                                  const SizedBox(height: 32),
                                  _buildActionButtons(),
                                  const SizedBox(height: 64),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          const Flexible(
            child: Text(
              'Exam Matrix Builder',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontFamily: 'Outfit',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF20B486), size: 20),
              SizedBox(width: 8),
              Text(
                'General Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            readOnly: widget.mode == MatrixMode.view,
            decoration: _inputDecoration('Matrix Title *', 'e.g. Midterm English Matrix', errorText: _titleError),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            decoration: _inputDecoration('Short Description', 'Enter a description for this matrix'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // Separate header widget for rules section (used in sliver layout)
  Widget _buildRulesHeader() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Exam Structure',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF20B486).withOpacity(0.3)),
              ),
              child: Text(
                'Total: $_totalQuestions questions',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButtons() {
    if (widget.mode == MatrixMode.view) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _addRule('single'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF20B486)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0xFF20B486), size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Add Single Question',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF20B486), fontFamily: 'Outfit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _addRule('group'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF20B486),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Add Reading Passage Group',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Outfit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleCard(int index) {
    final rule = _rules[index];
    final bool isGroup = rule['type'] == 'group';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Drag handle
              if (widget.mode != MatrixMode.view)
                Tooltip(
                  message: 'Hold to reorder',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.drag_indicator,
                          color: Color(0xFFCBD5E1),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isGroup ? const Color(0xFFFDF2F8) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getQuestionLabel(index),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isGroup ? const Color(0xFFDB2777) : const Color(0xFF16A34A),
                          fontFamily: 'Outfit',
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        isGroup ? 'Reading Passage Group' : 'Single Question',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.mode != MatrixMode.view)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _removeRule(index),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isGroup) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _inputDecoration('Skill *', null, errorText: rule['skillError']),
                    value: rule['skillId'],
                    items: _skills.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: widget.mode == MatrixMode.view ? null : (val) => setState(() => rule['skillId'] = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _inputDecoration('Difficulty *', null, errorText: rule['diffError']),
                    value: rule['diffId'],
                    items: _difficulties.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                    onChanged: widget.mode == MatrixMode.view ? null : (val) => setState(() => rule['diffId'] = val),
                  ),
                ),
              ],
            ),
          ] else ...[

            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: _inputDecoration('Group Type *', null, errorText: rule['groupTypeError']),
              value: rule['groupTypeId'],
              items: _groupTypes.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
              onChanged: widget.mode == MatrixMode.view ? null : (val) => setState(() => rule['groupTypeId'] = val),
            ),
            const SizedBox(height: 16),
            const Text('Sub Questions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
            const SizedBox(height: 8),
            ...(rule['subQuestions'] as List).asMap().entries.map((entry) {
              int subIdx = entry.key;
              var sq = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text('Q${subIdx + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: _inputDecoration('Skill *', null, errorText: sq['skillError']),
                        value: sq['skillId'],
                        items: _skills.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: widget.mode == MatrixMode.view ? null : (val) => setState(() => sq['skillId'] = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: _inputDecoration('Difficulty *', null, errorText: sq['diffError']),
                        value: sq['diffId'],
                        items: _difficulties.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                        onChanged: widget.mode == MatrixMode.view ? null : (val) => setState(() => sq['diffId'] = val),
                      ),
                    ),
                    if (widget.mode != MatrixMode.view)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeSubQuestion(index, subIdx),
                      ),
                  ],
                ),
              );
            }).toList(),
            if (widget.mode != MatrixMode.view)
              TextButton.icon(
                onPressed: () => _addSubQuestion(index),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF20B486)),
                label: const Text('Add Question to Group', style: TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: const Color(0xFF64748B),
          ),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        ),
        if (widget.mode != MatrixMode.view) ...[
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: !_isSaving ? _saveMatrix : null,
            icon: _isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 20),
            label: Text(_isSaving ? 'Saving...' : 'Save Matrix'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String? hint, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit', fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
