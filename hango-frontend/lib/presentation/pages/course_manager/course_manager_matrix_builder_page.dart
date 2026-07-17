import 'package:flutter/material.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/course_manager_sidebar.dart';

class CourseManagerMatrixBuilderPage extends StatefulWidget {
  final CourseManagerApi api;
  final VoidCallback onSaved;

  const CourseManagerMatrixBuilderPage({
    super.key,
    required this.api,
    required this.onSaved,
  });

  @override
  State<CourseManagerMatrixBuilderPage> createState() => _CourseManagerMatrixBuilderPageState();
}

class _CourseManagerMatrixBuilderPageState extends State<CourseManagerMatrixBuilderPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final List<Map<String, dynamic>> _rules = [];
  bool _isSaving = false;
  bool _isSidebarVisible = true;
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ToastHelper.showError(context, 'Failed to load parameters: $e');
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
            {'skillId': null, 'diffId': null}
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
      (_rules[ruleIndex]['subQuestions'] as List).add({'skillId': null, 'diffId': null});
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

  bool get _isValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_rules.isEmpty) return false;
    for (var r in _rules) {
      if (r['type'] == 'single') {
        if (r['skillId'] == null || r['diffId'] == null) return false;
      } else {
        if (r['groupTypeId'] == null) return false;
        final subQ = r['subQuestions'] as List;
        if (subQ.isEmpty) return false;
        for (var sq in subQ) {
          if (sq['skillId'] == null || sq['diffId'] == null) return false;
        }
      }
    }
    return true;
  }

  Future<void> _saveMatrix() async {
    if (!_isValid) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'details': _rules.map((r) {
          if (r['type'] == 'single') {
            return {
              'skillParamId': r['skillId'],
              'difficultyParamId': r['diffId'],
              'groupTypeParamId': r['groupTypeId'],
              'quantity': 1,
            };
          } else {
            return {
              'groupTypeParamId': r['groupTypeId'],
              'subQuestions': (r['subQuestions'] as List).map((sq) => {
                'skillParamId': sq['skillId'],
                'difficultyParamId': sq['diffId'],
                'quantity': 1,
              }).toList(),
            };
          }
        }).toList(),
      };

      await widget.api.createExamMatrix(data);
      if (mounted) {
        ToastHelper.showSuccess(context, 'Matrix created successfully!');
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Failed to create matrix: $e');
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
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'matrix')) : null,
      body: Row(
        children: [
          if (isDesktop && _isSidebarVisible)
            const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'matrix')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildContentHeader(context, isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 750),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGeneralInfoCard(),
                            const SizedBox(height: 32),
                            _isLoadingData 
                              ? const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(child: CircularProgressIndicator(color: Color(0xFF20B486))),
                                )
                              : _buildRulesSection(),
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
          ] else ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Exam Matrix Builder',
            style: TextStyle(
              color: Color(0xFF20B486),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
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
          TextFormField(
            controller: _titleController,
            decoration: _inputDecoration('Matrix Name *', 'E.g., High School Mock Exam 2026 Matrix'),
            onChanged: (_) => setState(() {}),
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

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Exam Structure',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Color(0xFF0F172A)),
            ),
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
        const SizedBox(height: 16),
        if (_rules.isEmpty)
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
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildRuleCard(index);
            },
          ),
        const SizedBox(height: 24),
        Row(
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
                      Text(
                        'Add Single Question',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF20B486), fontFamily: 'Outfit'),
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
                      Text(
                        'Add Reading Passage Group',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Text(
                    isGroup ? 'Reading Passage Group' : 'Single Question',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
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
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _inputDecoration('Skill *', null),
                    value: rule['skillId'],
                    items: _skills.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => rule['skillId'] = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    decoration: _inputDecoration('Group Type (Optional)', null),
                    value: rule['groupTypeId'],
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('None', style: TextStyle(color: Colors.grey))),
                      ..._groupTypes.map((s) => DropdownMenuItem<int?>(value: s['id'], child: Text(s['name'])))
                    ],
                    onChanged: (val) => setState(() => rule['groupTypeId'] = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: _inputDecoration('Difficulty *', null),
                    value: rule['diffId'],
                    items: _difficulties.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                    onChanged: (val) => setState(() => rule['diffId'] = val),
                  ),
                ),
              ],
            ),
          ] else ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: _inputDecoration('Group Type *', null),
              value: rule['groupTypeId'],
              items: _groupTypes.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
              onChanged: (val) => setState(() => rule['groupTypeId'] = val),
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
                        decoration: _inputDecoration('Skill *', null),
                        value: sq['skillId'],
                        items: _skills.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => sq['skillId'] = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: _inputDecoration('Difficulty *', null),
                        value: sq['diffId'],
                        items: _difficulties.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                        onChanged: (val) => setState(() => sq['diffId'] = val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => _removeSubQuestion(index, subIdx),
                    ),
                  ],
                ),
              );
            }).toList(),
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
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: (_isValid && !_isSaving) ? _saveMatrix : null,
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
    );
  }

  InputDecoration _inputDecoration(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
