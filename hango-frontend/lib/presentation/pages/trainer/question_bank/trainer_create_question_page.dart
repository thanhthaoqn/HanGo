import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/config.dart';
import '../../login_page.dart';
import '../trainer_courses_page.dart';
import '../trainer_dashboard_page.dart';
import '../trainer_exams_page.dart';
import 'trainer_question_bank_page.dart';
import '../../../../services/hango_api.dart';
import 'models/trainer_question.dart';

class OptionState {
  int? id;
  TextEditingController textController = TextEditingController();
  bool isCorrect;
  OptionState({this.id, String text = '', this.isCorrect = false}) {
    textController.text = text;
  }
}

class QuestionState {
  int? id;
  TextEditingController questionTextController = TextEditingController();
  TextEditingController explanationController = TextEditingController();
  int? selectedSkillId;
  int? selectedDifficultyId;
  List<OptionState> options = [];

  QuestionState() {
    options = [
      OptionState(text: '', isCorrect: true),
      OptionState(text: '', isCorrect: false),
      OptionState(text: '', isCorrect: false),
      OptionState(text: '', isCorrect: false),
    ];
  }
}

class TrainerCreateQuestionPage extends StatefulWidget {
  final TrainerQuestion? question;
  final bool isReadOnly;
  final bool isEdit;

  const TrainerCreateQuestionPage({
    Key? key,
    this.question,
    this.isReadOnly = false,
    this.isEdit = false,
  }) : super(key: key);

  @override
  State<TrainerCreateQuestionPage> createState() => _TrainerCreateQuestionPageState();
}

class _TrainerCreateQuestionPageState extends State<TrainerCreateQuestionPage> {
  final _authService = AuthService();
  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _isQuestionGroup = true;
  bool _isLoadingMetadata = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _groupTypes = [];
  List<Map<String, dynamic>> _difficulties = [];

  int? _selectedGroupTypeId;
  String _status = 'PRIVATE';

  final TextEditingController _passageController = TextEditingController();
  List<QuestionState> _questions = [QuestionState()];

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _loadMetadata();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
      _trainerAvatarUrl = avatarUrl;
    });
  }

  Future<HangoApi> _getApi() async {
    final token = await _authService.getToken();
    final String apiBaseUrl = EnvConfig.apiBaseUrl;
    return HangoApi(baseUrl: apiBaseUrl, token: token);
  }

  Future<void> _loadMetadata() async {
    try {
      final api = await _getApi();
      final skills = await api.getSystemParameters('SKILL_TYPE');
      final difficulties = await api.getSystemParameters('DIFFICULTY');
      final groupTypes = await api.getQuestionCategories();

      Map<String, dynamic>? detail;
      if (widget.question != null) {
        final q = widget.question!;
        try {
          detail = await api.getTrainerQuestionDetail(q.id, isGroup: q.isGroup);
        } catch (e) {
          print("Error loading detail: $e");
        }
      }

      setState(() {
        _skills = skills;
        _difficulties = difficulties;
        _groupTypes = groupTypes;

        if (_skills.isNotEmpty) {
          for (var q in _questions) {
            q.selectedSkillId = _skills.first['id'] as int;
          }
        }
        if (_difficulties.isNotEmpty) {
          for (var q in _questions) {
            q.selectedDifficultyId = _difficulties.first['id'] as int;
          }
        }
        if (_groupTypes.isNotEmpty) _selectedGroupTypeId = _groupTypes.first['id'] as int;

        if (widget.question != null) {
          final q = widget.question!;
          _isQuestionGroup = q.isGroup;
          
          if (detail != null) {
            _selectedGroupTypeId = detail['categoryId'] as int?;
            
            if (q.isGroup) {
              _passageController.text = detail['passageText'] ?? '';
            }

            final subQList = detail['subQuestions'] as List? ?? [];
            _questions = [];
            for (var subQ in subQList) {
              final qs = QuestionState();
              qs.id = subQ['id'] as int?;
              qs.questionTextController.text = subQ['questionText'] ?? '';
              qs.explanationController.text = subQ['explanation'] ?? '';
              qs.selectedSkillId = subQ['skillParamId'] as int? ?? (_skills.isNotEmpty ? _skills.first['id'] : null);
              qs.selectedDifficultyId = subQ['difficultyId'] as int? ?? (_difficulties.isNotEmpty ? _difficulties.first['id'] : null);
              
              final optsList = subQ['options'] as List? ?? [];
              qs.options = [];
              for (var opt in optsList) {
                qs.options.add(OptionState(
                  id: opt['id'] as int?,
                  text: opt['optionText'] ?? '',
                  isCorrect: opt['isCorrect'] as bool? ?? false,
                ));
              }
              // Fallback if empty options
              if (qs.options.isEmpty) {
                qs.options = [
                  OptionState(text: '', isCorrect: true),
                  OptionState(text: '', isCorrect: false),
                  OptionState(text: '', isCorrect: false),
                  OptionState(text: '', isCorrect: false),
                ];
              }
              _questions.add(qs);
            }
            _status = detail['status'] ?? 'PRIVATE';
          } else {
            // Fallback to simple data
            _questions = [QuestionState()];
            _questions[0].questionTextController.text = widget.question!.questionText;
            _status = widget.question!.status;
          }
        }

        _isLoadingMetadata = false;
      });
    } catch (e) {
      print('Error loading metadata: $e');
      setState(() => _isLoadingMetadata = false);
      if (mounted) {
        ToastHelper.show(context, 'Failed to load metadata: $e', isError: true);
      }
    }
  }

  Future<void> _handleSave() async {
    // Validate
    if (_isQuestionGroup && _passageController.text.trim().isEmpty) {
      ToastHelper.show(context, 'Passage text cannot be empty for a Question Group.', isError: true);
      return;
    }
    for (var i = 0; i < _questions.length; i++) {
      if (_questions[i].selectedSkillId == null) {
        ToastHelper.show(context, 'Question ${i + 1} must have a Skill Type.', isError: true);
        return;
      }
      if (_questions[i].selectedDifficultyId == null) {
        ToastHelper.show(context, 'Question ${i + 1} must have a Difficulty.', isError: true);
        return;
      }
      if (_questions[i].questionTextController.text.trim().isEmpty) {
        ToastHelper.show(context, 'Question ${i + 1} text cannot be empty.', isError: true);
        return;
      }
      if (!_questions[i].options.any((opt) => opt.isCorrect)) {
        ToastHelper.show(context, 'Question ${i + 1} must have at least one correct option.', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        if (widget.question != null) 'id': widget.question!.id,
        'categoryId': _selectedGroupTypeId,
        'status': _status,
        'passageText': _isQuestionGroup ? _passageController.text : null,
        'subQuestions': _questions.map((q) => {
          if (q.id != null) 'id': q.id,
          'questionText': q.questionTextController.text,
          'explanation': q.explanationController.text,
          'skillParamId': q.selectedSkillId,
          'difficultyId': q.selectedDifficultyId,
          'options': q.options.map((o) => {
            if (o.id != null) 'id': o.id,
            'optionText': o.textController.text,
            'isCorrect': o.isCorrect,
          }).toList()
        }).toList(),
      };

      final api = await _getApi();
      if (widget.question != null) {
        await api.updateTrainerQuestionGroup(widget.question!.id, payload, isGroup: widget.question!.isGroup);
      } else {
        await api.createTrainerQuestionGroup(payload);
      }

      if (mounted) {
        ToastHelper.show(context, 'Question saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Failed to save question: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: _isLoadingMetadata
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF38C9A6)))
                      : _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isReadOnly ? 'View Question' : (widget.isEdit ? 'Edit Question' : 'Create Question'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 12,
                child: _buildLeftColumn(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 10,
                child: _buildRightColumn(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        _buildPassageEditor(),
        const SizedBox(height: 16),
        _buildMetadataSection(),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTypeToggle(),
        const SizedBox(height: 16),
        if (_isQuestionGroup) _buildQuestionGroupUI() else _buildSingleQuestionUI(),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: Colors.white,
          ),
          child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
        ),
        if (!widget.isReadOnly) ...[
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38C9A6),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          ),
        ],
      ],
    );
  }

  Widget _buildPassageEditor() {
    final title = _isQuestionGroup ? 'PASSAGE' : 'QUESTION';
    final icon = _isQuestionGroup ? Icons.article_outlined : Icons.help_outline;
    final hint = _isQuestionGroup ? 'Enter passage content here...' : 'Enter question text here...';
    final controller = _isQuestionGroup ? _passageController : _questions[0].questionTextController;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF38C9A6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF38C9A6),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            maxLines: 15,
            readOnly: widget.isReadOnly,
            decoration: InputDecoration(
              hintText: hint,
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
                borderSide: const BorderSide(color: Color(0xFF38C9A6)),
              ),
              filled: true,
              fillColor: widget.isReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (!_isQuestionGroup) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('SKILL TYPE'),
                      _buildDropdown(
                        value: _questions.isNotEmpty ? _questions[0].selectedSkillId : null,
                        items: _skills,
                        onChanged: widget.isReadOnly ? null : (val) {
                          if (_questions.isNotEmpty) {
                            setState(() => _questions[0].selectedSkillId = val);
                          }
                        },
                        displayKey: 'paramValue',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('GROUP TYPE'),
                      _buildDropdown(
                        value: _selectedGroupTypeId,
                        items: _groupTypes,
                        onChanged: widget.isReadOnly ? null : (val) => setState(() => _selectedGroupTypeId = val),
                        displayKey: 'name',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('DIFFICULTY'),
                      _buildDropdown(
                        value: _questions.isNotEmpty ? _questions[0].selectedDifficultyId : null,
                        items: _difficulties,
                        onChanged: widget.isReadOnly ? null : (val) {
                          if (_questions.isNotEmpty) {
                            setState(() => _questions[0].selectedDifficultyId = val);
                          }
                        },
                        displayKey: 'paramValue',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('STATUS'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.isReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _status,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            onChanged: widget.isReadOnly ? null : (val) {
                              if (val != null) setState(() => _status = val);
                            },
                            items: const [
                              DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
                              DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('GROUP TYPE'),
                      _buildDropdown(
                        value: _selectedGroupTypeId,
                        items: _groupTypes,
                        onChanged: widget.isReadOnly ? null : (val) => setState(() => _selectedGroupTypeId = val),
                        displayKey: 'name',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('STATUS'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.isReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _status,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                            onChanged: widget.isReadOnly ? null : (val) {
                              if (val != null) setState(() => _status = val);
                            },
                            items: const [
                              DropdownMenuItem(value: 'PRIVATE', child: Text('Private')),
                              DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required int? value,
    required List<Map<String, dynamic>> items,
    required Function(int?)? onChanged,
    required String displayKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          items: items.map((item) {
            return DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(item[displayKey] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildQuestionTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('QUESTION TYPE'),
          Row(
            children: [
              _buildToggleButton(
                title: 'Question Group',
                icon: Icons.check_box_outlined,
                isActive: _isQuestionGroup,
                onTap: widget.isReadOnly ? () {} : () {
                  setState(() {
                    _isQuestionGroup = true;
                  });
                },
              ),
              const SizedBox(width: 12),
              _buildToggleButton(
                title: 'Single Question',
                icon: Icons.edit_note_outlined,
                isActive: !_isQuestionGroup,
                onTap: widget.isReadOnly ? () {} : () {
                  setState(() {
                    _isQuestionGroup = false;
                    if (_questions.length > 1) {
                      _questions = [_questions.first]; // Keep only first question
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String title, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF38C9A6) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? const Color(0xFF38C9A6) : const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(icon, color: isActive ? Colors.white : const Color(0xFF1E293B)),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionGroupUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ANSWER DETAILS'),
        for (var i = 0; i < _questions.length; i++) ...[
          _buildQuestionCard(i),
          const SizedBox(height: 12),
        ],
        // Add Answer Set Button
        if (!widget.isReadOnly)
          InkWell(
            onTap: () {
              setState(() {
                final newQ = QuestionState();
                if (_skills.isNotEmpty) newQ.selectedSkillId = _skills.first['id'] as int;
                if (_difficulties.isNotEmpty) newQ.selectedDifficultyId = _difficulties.first['id'] as int;
                _questions.add(newQ);
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5), 
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, size: 20, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Text(
                    'Add Answer Set',
                    style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleQuestionUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ANSWER DETAILS'),
        _buildQuestionCard(0, showTitle: false, showQuestionText: false),
      ],
    );
  }

  Widget _buildQuestionCard(int index, {bool showTitle = true, bool showQuestionText = true}) {
    final qState = _questions[index];
    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38C9A6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (_questions.length > 1 && !widget.isReadOnly)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _questions.removeAt(index);
                        });
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isQuestionGroup) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('SKILL TYPE'),
                            _buildDropdown(
                              value: qState.selectedSkillId,
                              items: _skills,
                              onChanged: widget.isReadOnly ? null : (val) => setState(() => qState.selectedSkillId = val),
                              displayKey: 'paramValue',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('DIFFICULTY'),
                            _buildDropdown(
                              value: qState.selectedDifficultyId,
                              items: _difficulties,
                              onChanged: widget.isReadOnly ? null : (val) => setState(() => qState.selectedDifficultyId = val),
                              displayKey: 'paramValue',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (showQuestionText) ...[
                  _buildLabel('QUESTION'),
                  TextField(
                    controller: qState.questionTextController,
                    readOnly: widget.isReadOnly,
                    decoration: InputDecoration(
                      hintText: 'Enter question text...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: const OutlineInputBorder(),
                      fillColor: widget.isReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                      filled: widget.isReadOnly,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildLabel('OPTIONS (Select correct answer)'),
                for (var optIndex = 0; optIndex < qState.options.length; optIndex++) ...[
                  _buildOptionRow(qState, optIndex, letters[optIndex]),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                _buildLabel('EXPLANATION (Optional)'),
                TextField(
                  controller: qState.explanationController,
                  maxLines: 2,
                  readOnly: widget.isReadOnly,
                  decoration: InputDecoration(
                    hintText: 'Add explanation...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: const OutlineInputBorder(),
                    fillColor: widget.isReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                    filled: widget.isReadOnly,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(QuestionState qState, int optIndex, String letter) {
    final option = qState.options[optIndex];
    
    return Row(
      children: [
        InkWell(
          onTap: widget.isReadOnly ? null : () {
            setState(() {
              for (var o in qState.options) {
                o.isCorrect = false;
              }
              option.isCorrect = true;
            });
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.isCorrect ? const Color(0xFF0F766E) : Colors.white,
              border: Border.all(color: option.isCorrect ? const Color(0xFF0F766E) : const Color(0xFF94A3B8)),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                color: option.isCorrect ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: option.textController,
            readOnly: widget.isReadOnly,
            decoration: InputDecoration(
              hintText: 'Option $letter',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: option.isCorrect ? const Color(0xFF38C9A6) : const Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: option.isCorrect ? const Color(0xFF38C9A6) : const Color(0xFFE2E8F0)),
              ),
              filled: option.isCorrect || widget.isReadOnly,
              fillColor: option.isCorrect ? const Color(0xFFE2F9F3) : (widget.isReadOnly ? const Color(0xFFF1F5F9) : Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  // --- Sidebar & Header ---
  
  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2F9F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 18,
                    color: Color(0xFF38C9A6),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildSidebarItem(
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
              );
            },
          ),
          _buildSidebarItem(Icons.book_outlined, 'Courses', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerCoursesPage()),
            );
          }),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam', onTap: () {
             Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerExamsPage()),
            );
          }),
          _buildSidebarItem(Icons.folder_open_outlined, 'Question Bank', isSelected: true, onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerQuestionBankPage()),
            );
          }),
          const Spacer(),
          _buildSidebarItem(Icons.logout, 'Log out', isLogout: true, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isSelected = false, bool isLogout = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isLogout
                  ? const Color(0xFFEF4444)
                  : (isSelected ? const Color(0xFF38C9A6) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isLogout
                    ? const Color(0xFFEF4444)
                    : (isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          const SizedBox(width: 8),
          const Text(
            'Question Bank',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Text(
            '  >  ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFCBD5E1),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Text(
            'Create New Question',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF0F766E),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.notifications_none, size: 20, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              if (_trainerAvatarUrl.isNotEmpty)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(_trainerAvatarUrl),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF38C9A6),
                  child: Text(
                    _trainerInitials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _trainerName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const Text(
                    'Trainer',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
