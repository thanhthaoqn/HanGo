import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/config.dart';
import '../../../widgets/trainer/trainer_sidebar.dart';
import '../../../../services/hango_api.dart';
import 'models/course_manager_question.dart';
import '../../../widgets/course_manager_sidebar.dart';
import '../../../widgets/shared_header.dart';
import '../../../../data/repositories/trainer_ai_recommendation_repository.dart';

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

class CourseManagerCreateQuestionPage extends StatefulWidget {
  final CourseManagerQuestion? question;
  final bool isReadOnly;
  final bool isEdit;
  final bool isCourseManager;
  final Map<String, dynamic>? initialData;

  const CourseManagerCreateQuestionPage({
    Key? key,
    this.question,
    this.isReadOnly = false,
    this.isEdit = false,
    this.isCourseManager = false,
    this.initialData,
  }) : super(key: key);

  @override
  State<CourseManagerCreateQuestionPage> createState() => _CourseManagerCreateQuestionPageState();
}

class _CourseManagerCreateQuestionPageState extends State<CourseManagerCreateQuestionPage> {
  final _authService = AuthService();
  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _isQuestionGroup = true;
  bool _isLoadingMetadata = true;
  bool _isSaving = false;
  bool _isGeneratingByAi = false;
  int _aiQuantity = 2;
  int? _globalSkillId;
  int? _globalDifficultyId;

  final TrainerAiQuestionRepository _aiRepo = TrainerAiQuestionRepository();

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
      final groupTypes = await api.getSystemParameters('GROUP_TYPE');

      Map<String, dynamic>? detail;
      if (widget.initialData != null) {
        detail = widget.initialData;
      } else if (widget.question != null) {
        final q = widget.question!;
        try {
          detail = await api.getCourseManagerQuestionDetail(q.id, isGroup: q.isGroup);
        } catch (e) {
          print("Error loading detail: $e");
        }
      }

      setState(() {
        _skills = skills;
        _difficulties = difficulties;
        _groupTypes = groupTypes;

        if (widget.initialData != null || widget.question != null) {
          final isGroup = widget.initialData != null 
              ? (widget.initialData!['isGroup'] as bool? ?? false) 
              : widget.question!.isGroup;
          _isQuestionGroup = isGroup;
          
          if (detail != null) {
            if (widget.initialData != null) {
              // Resolve names to IDs for Excel Import
              String gName = detail['groupTypeName'] ?? '';
              if (gName.isNotEmpty) {
                var match = _groupTypes.firstWhere(
                  (t) => t['paramValue'].toString().toLowerCase() == gName.toLowerCase(),
                  orElse: () => <String, dynamic>{},
                );
                _selectedGroupTypeId = match['id'] as int?;
              }
            } else {
              _selectedGroupTypeId = detail['categoryId'] as int?;
            }
            
            if (isGroup) {
              _passageController.text = detail['passageText'] ?? '';
            }

            final subQList = detail['subQuestions'] as List? ?? [];
            _questions = [];
            for (var subQ in subQList) {
              final qs = QuestionState();
              qs.id = subQ['id'] as int?;
              qs.questionTextController.text = subQ['questionText'] ?? '';
              qs.explanationController.text = subQ['explanation'] ?? '';
              if (widget.initialData != null) {
                // Resolve names to IDs for Excel Import
                String sName = subQ['skillName'] ?? '';
                if (sName.isNotEmpty) {
                  var match = _skills.firstWhere(
                    (t) => t['paramValue'].toString().toLowerCase() == sName.toLowerCase(),
                    orElse: () => <String, dynamic>{},
                  );
                  qs.selectedSkillId = match['id'] as int?;
                }
                String dName = subQ['diffName'] ?? '';
                if (dName.isNotEmpty) {
                  var match = _difficulties.firstWhere(
                    (t) => t['paramValue'].toString().toLowerCase() == dName.toLowerCase(),
                    orElse: () => <String, dynamic>{},
                  );
                  qs.selectedDifficultyId = match['id'] as int?;
                }
              } else {
                qs.selectedSkillId = subQ['skillParamId'] as int?;
                qs.selectedDifficultyId = subQ['difficultyId'] as int?;
              }
              
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

  Future<void> _handleGenerateByAI() async {
    setState(() {
      _isGeneratingByAi = true;
    });

    try {
      final String mode = _isQuestionGroup ? 'MULTIPLE' : 'SINGLE';
      
      String? groupTypeName;
      if (_isQuestionGroup && _selectedGroupTypeId != null) {
        final match = _groupTypes.firstWhere(
          (t) => t['id'] == _selectedGroupTypeId,
          orElse: () => <String, dynamic>{},
        );
        groupTypeName = match['paramValue']?.toString();
      }
      
      String? skillTypeName;
      if (_globalSkillId != null) {
        final match = _skills.firstWhere(
          (t) => t['id'] == _globalSkillId,
          orElse: () => <String, dynamic>{},
        );
        skillTypeName = match['paramValue']?.toString();
      }

      final resp = await _aiRepo.generate(
        mode: mode,
        sectionId: 1, // Dummy sectionId required by backend DTO
        topicSeed: skillTypeName ?? 'English test questions', // Dummy topic if no topic input
        quantity: _isQuestionGroup ? _aiQuantity : 1,
        difficultyId: _globalDifficultyId,
        categoryId: _selectedGroupTypeId,
        skillType: skillTypeName,
        groupType: groupTypeName,
      );

      if (_isQuestionGroup && resp.group != null) {
        if (resp.group!.passageText.isNotEmpty) {
          _passageController.text = resp.group!.passageText;
        }
        
        final generatedSubs = resp.group!.subQuestions;
        if (generatedSubs.isEmpty) {
          ToastHelper.showError(context, 'AI did not return any sub-questions.');
          return;
        }

        _questions.clear();
        for (final q in generatedSubs) {
          final opts = <Map<String, dynamic>>[];
          for (final o in q.options) {
            opts.add({
              'optionText': o.optionText,
              'isCorrect': o.isCorrect,
            });
          }
          
          final qs = QuestionState();
          qs.questionTextController.text = q.questionText;
          qs.explanationController.text = q.explanation;
          qs.selectedSkillId = _globalSkillId;
          qs.selectedDifficultyId = _globalDifficultyId;
          
          qs.options = [];
          for (var opt in opts) {
            qs.options.add(OptionState(
              text: opt['optionText'] ?? '',
              isCorrect: opt['isCorrect'] as bool? ?? false,
            ));
          }
          _questions.add(qs);
        }
      } else {
        final generated = resp.questions ?? [];
        if (generated.isEmpty) {
          ToastHelper.showError(context, 'AI did not return any questions.');
          return;
        }

        _questions.clear();
        for (final q in generated) {
          final opts = <Map<String, dynamic>>[];
          for (final o in q.options) {
            opts.add({
              'optionText': o.optionText,
              'isCorrect': o.isCorrect,
            });
          }
          
          final qs = QuestionState();
          qs.questionTextController.text = q.questionText;
          qs.explanationController.text = q.explanation;
          qs.selectedSkillId = _globalSkillId;
          qs.selectedDifficultyId = _globalDifficultyId;
          
          qs.options = [];
          for (var opt in opts) {
            qs.options.add(OptionState(
              text: opt['optionText'] ?? '',
              isCorrect: opt['isCorrect'] as bool? ?? false,
            ));
          }
          _questions.add(qs);
        }
      }
      
      ToastHelper.show(context, 'Questions generated successfully!');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'AI Generation Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingByAi = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    // Validate
    if (_isQuestionGroup && _passageController.text.trim().isEmpty) {
      ToastHelper.show(context, 'Passage text cannot be empty for a Question Group.', isError: true);
      return;
    }
    if (_isQuestionGroup && _selectedGroupTypeId == null) {
      ToastHelper.show(context, 'Please select a Group Type.', isError: true);
      return;
    }
    for (var i = 0; i < _questions.length; i++) {
      if (_questions[i].selectedSkillId == null) {
        ToastHelper.show(context, 'Please select a Skill Type for Question ${i + 1}.', isError: true);
        return;
      }
      if (_questions[i].selectedDifficultyId == null) {
        ToastHelper.show(context, 'Please select a Difficulty for Question ${i + 1}.', isError: true);
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
        await api.updateCourseManagerQuestionGroup(widget.question!.id, payload, isGroup: widget.question!.isGroup);
      } else {
        await api.createCourseManagerQuestionGroup(payload);
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isCourseManager
          ? SharedHeader(
              isDesktop: isDesktop,
              activeTab: '',
              hideNavLinks: true,
              hideCommerceActions: true,
              hideLanguageSwitcher: true,
            )
          : null,
      drawer: !isDesktop 
          ? (widget.isCourseManager ? const Drawer(child: CourseManagerSidebar(currentRoute: 'question_bank')) : const Drawer(child: TrainerSidebar(activeIndex: 3)))
          : null,
      body: Row(
        children: [
          if (isDesktop) 
            SizedBox(
              width: widget.isCourseManager ? 240 : 260, 
              child: widget.isCourseManager ? const CourseManagerSidebar(currentRoute: 'question_bank') : const TrainerSidebar(activeIndex: 3)
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isCourseManager) _buildHeader(context, !isDesktop),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('SKILL TYPE'),
                    _buildDropdown(
                      value: _globalSkillId ?? (_questions.isNotEmpty ? _questions[0].selectedSkillId : null),
                      items: _skills,
                      onChanged: widget.isReadOnly ? null : (val) {
                        setState(() {
                          _globalSkillId = val;
                          if (!_isQuestionGroup && _questions.isNotEmpty) {
                            _questions[0].selectedSkillId = val;
                          }
                        });
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
                    _buildLabel('DIFFICULTY'),
                    _buildDropdown(
                      value: _globalDifficultyId ?? (_questions.isNotEmpty ? _questions[0].selectedDifficultyId : null),
                      items: _difficulties,
                      onChanged: widget.isReadOnly ? null : (val) {
                        setState(() {
                          _globalDifficultyId = val;
                          if (!_isQuestionGroup && _questions.isNotEmpty) {
                            _questions[0].selectedDifficultyId = val;
                          }
                        });
                      },
                      displayKey: 'paramValue',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('GROUP TYPE'),
              _buildDropdown(
                value: _selectedGroupTypeId,
                items: _groupTypes,
                onChanged: widget.isReadOnly ? null : (val) => setState(() => _selectedGroupTypeId = val),
                displayKey: 'paramValue',
                allowNone: true,
              ),
            ],
          ),
          if (_isQuestionGroup) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Number of Questions (AI Generate)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16, color: Color(0xFF64748B)),
                        onPressed: widget.isReadOnly ? null : () {
                          setState(() {
                            if (_aiQuantity > 2) _aiQuantity--;
                          });
                        },
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$_aiQuantity',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                        onPressed: widget.isReadOnly ? null : () {
                          setState(() {
                            if (_aiQuantity < 10) _aiQuantity++;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isGeneratingByAi ||
                          _globalSkillId == null ||
                          _globalDifficultyId == null ||
                          (_isQuestionGroup && _selectedGroupTypeId == null))
                  ? null
                  : _handleGenerateByAI,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: _isGeneratingByAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Generate by AI', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38C9A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required int? value,
    required List<Map<String, dynamic>> items,
    required Function(int?)? onChanged,
    required String displayKey,
    bool allowNone = false,
  }) {
    final bool valueExists = value == null || items.any((item) => item['id'] == value);
    final int? safeValue = valueExists ? value : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          items: [
            if (allowNone)
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('None', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
              ),
            ...items.map((item) {
              return DropdownMenuItem<int?>(
                value: item['id'] as int?,
                child: Text(item[displayKey] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
              );
            }),
          ],
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
