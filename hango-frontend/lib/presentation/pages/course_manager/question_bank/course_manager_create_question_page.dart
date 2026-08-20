import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/config.dart';
import '../../../widgets/trainer/trainer_sidebar.dart';
import '../../../../services/hango_api.dart';
import 'models/course_manager_question.dart';
import '../../../widgets/course_manager_sidebar.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
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
  String? skillError;
  String? difficultyError;
  String? questionTextError;
  String? optionsError;
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

class QuestionGroupState {
  bool isGroup;
  TextEditingController passageController = TextEditingController();
  int? selectedGroupTypeId;
  String? passageError;
  String? groupTypeError;
  int aiQuantity = 2;
  List<QuestionState> questions = [QuestionState()];
  
  QuestionGroupState({this.isGroup = false});
}

class CourseManagerCreateQuestionPage extends StatefulWidget {
  final CourseManagerQuestion? question;
  final bool isReadOnly;
  final bool isEdit;
  final bool isCourseManager;
  final Map<String, dynamic>? initialData;
  final bool isEmbedded;
  final VoidCallback? onBack;

  const CourseManagerCreateQuestionPage({
    Key? key,
    this.question,
    this.isReadOnly = false,
    this.isEdit = false,
    this.isCourseManager = false,
    this.initialData,
    this.isEmbedded = false,
    this.onBack,
  }) : super(key: key);

  @override
  State<CourseManagerCreateQuestionPage> createState() => _CourseManagerCreateQuestionPageState();
}

class _CourseManagerCreateQuestionPageState extends State<CourseManagerCreateQuestionPage> {
  final _authService = AuthService();

  bool _isLoadingMetadata = true;
  bool _isSaving = false;
  bool _isGeneratingByAi = false;

  final TrainerAiQuestionRepository _aiRepo = TrainerAiQuestionRepository();

  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _groupTypes = [];
  List<Map<String, dynamic>> _difficulties = [];

  String _status = 'PRIVATE';

  List<QuestionGroupState> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  void _goBack() {
    if (widget.isEmbedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
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

        if (widget.initialData != null) {
          final groupsList = widget.initialData!['groups'] as List? ?? [];
          _groups = [];

          for (var groupData in groupsList) {
            final isGroup = groupData['isGroup'] as bool? ?? false;
            final gState = QuestionGroupState(isGroup: isGroup);
            
            if (isGroup) {
              gState.passageController.text = groupData['passageText'] ?? '';
              String gName = groupData['groupTypeName'] ?? '';
              if (gName.isNotEmpty) {
                var match = _groupTypes.firstWhere(
                  (t) => t['paramValue'].toString().toLowerCase() == gName.toLowerCase(),
                  orElse: () => <String, dynamic>{},
                );
                gState.selectedGroupTypeId = match['id'] as int?;
              }
            }

            final subQList = groupData['subQuestions'] as List? ?? [];
            gState.questions = [];
            for (var subQ in subQList) {
              final qs = QuestionState();
              qs.id = subQ['id'] as int?;
              qs.questionTextController.text = subQ['questionText'] ?? '';
              qs.explanationController.text = subQ['explanation'] ?? '';
              
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

              final optsList = subQ['options'] as List? ?? [];
              qs.options = [];
              for (var opt in optsList) {
                qs.options.add(OptionState(
                  id: opt['id'] as int?,
                  text: opt['optionText'] ?? '',
                  isCorrect: opt['isCorrect'] as bool? ?? false,
                ));
              }
              if (qs.options.isEmpty) {
                qs.options = [
                  OptionState(text: '', isCorrect: true),
                  OptionState(text: '', isCorrect: false),
                  OptionState(text: '', isCorrect: false),
                  OptionState(text: '', isCorrect: false),
                ];
              }
              gState.questions.add(qs);
            }
            if (gState.questions.isEmpty) gState.questions.add(QuestionState());
            _groups.add(gState);
          }
          if (_groups.isEmpty) _groups.add(QuestionGroupState(isGroup: true));
        } else if (widget.question != null && detail != null) {
          final isGroup = widget.question!.isGroup;
          final gState = QuestionGroupState(isGroup: isGroup);
          
          if (isGroup) {
            gState.passageController.text = detail['passageText'] ?? '';
            gState.selectedGroupTypeId = detail['categoryId'] as int?;
          }

          final subQList = detail['subQuestions'] as List? ?? [];
          gState.questions = [];
          for (var subQ in subQList) {
            final qs = QuestionState();
            qs.id = subQ['id'] as int?;
            qs.questionTextController.text = subQ['questionText'] ?? '';
            qs.explanationController.text = subQ['explanation'] ?? '';
            qs.selectedSkillId = subQ['skillParamId'] as int?;
            qs.selectedDifficultyId = subQ['difficultyId'] as int?;
            
            final optsList = subQ['options'] as List? ?? [];
            qs.options = [];
            for (var opt in optsList) {
              qs.options.add(OptionState(
                id: opt['id'] as int?,
                text: opt['optionText'] ?? '',
                isCorrect: opt['isCorrect'] as bool? ?? false,
              ));
            }
            if (qs.options.isEmpty) {
              qs.options = [
                OptionState(text: '', isCorrect: true),
                OptionState(text: '', isCorrect: false),
                OptionState(text: '', isCorrect: false),
                OptionState(text: '', isCorrect: false),
              ];
            }
            gState.questions.add(qs);
          }
          if (gState.questions.isEmpty) gState.questions.add(QuestionState());
          _groups = [gState];
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

  /// Picks the id to use for a generated sub-question's skill/difficulty dropdown:
  /// prefer the AI's per-question suggestion (validated against the loaded options),
  /// then the value the trainer had already selected, then the first available option,
  /// so the field is never left blank after AI generation.
  int? _resolveMetadataId(int? aiSuggestedId, int? fallbackId, List<Map<String, dynamic>> options) {
    if (aiSuggestedId != null && options.any((o) => o['id'] == aiSuggestedId)) {
      return aiSuggestedId;
    }
    if (fallbackId != null && options.any((o) => o['id'] == fallbackId)) {
      return fallbackId;
    }
    return options.isNotEmpty ? options.first['id'] as int? : null;
  }

  Future<void> _handleGenerateByAIForGroup(QuestionGroupState group) async {
    setState(() {
      _isGeneratingByAi = true;
    });

    try {
      final String mode = group.isGroup ? 'MULTIPLE' : 'SINGLE';
      
      String? groupTypeName;
      if (group.selectedGroupTypeId != null) {
        final match = _groupTypes.firstWhere(
          (t) => t['id'] == group.selectedGroupTypeId,
          orElse: () => <String, dynamic>{},
        );
        groupTypeName = match['paramValue']?.toString();
      }
      
      // We will try to infer a skill and difficulty from the first question, if any.
      int? firstSkillId = group.questions.isNotEmpty ? group.questions.first.selectedSkillId : null;
      int? firstDiffId = group.questions.isNotEmpty ? group.questions.first.selectedDifficultyId : null;

      String? skillTypeName;
      if (firstSkillId != null) {
        final match = _skills.firstWhere(
          (t) => t['id'] == firstSkillId,
          orElse: () => <String, dynamic>{},
        );
        skillTypeName = match['paramValue']?.toString();
      }

      final resp = await _aiRepo.generate(
        mode: mode,
        sectionId: 1, 
        topicSeed: skillTypeName ?? 'English test questions', 
        quantity: group.isGroup ? group.aiQuantity : 1,
        difficultyId: firstDiffId,
        categoryId: group.selectedGroupTypeId,
        skillType: skillTypeName,
        groupType: groupTypeName,
      );

      if (group.isGroup && resp.group != null) {
        if (resp.group!.passageText.isNotEmpty) {
          group.passageController.text = resp.group!.passageText;
        }
        
        final generatedSubs = resp.group!.subQuestions;
        if (generatedSubs.isEmpty) {
          if (mounted) ToastHelper.showError(context, 'AI did not return any sub-questions.');
          return;
        }

        group.questions.clear();
        for (final q in generatedSubs) {
          final qs = QuestionState();
          qs.questionTextController.text = q.questionText;
          qs.explanationController.text = q.explanation;
          qs.selectedSkillId = _resolveMetadataId(q.skillParamId, firstSkillId, _skills);
          qs.selectedDifficultyId = _resolveMetadataId(q.difficultyId, firstDiffId, _difficulties);

          qs.options = [];
          for (final o in q.options) {
            qs.options.add(OptionState(
              text: o.optionText,
              isCorrect: o.isCorrect,
            ));
          }
          group.questions.add(qs);
        }
      } else {
        final generated = resp.questions ?? [];
        if (generated.isEmpty) {
          if (mounted) ToastHelper.showError(context, 'AI did not return any questions.');
          return;
        }

        group.questions.clear();
        for (final q in generated) {
          final qs = QuestionState();
          qs.questionTextController.text = q.questionText;
          qs.explanationController.text = q.explanation;
          qs.selectedSkillId = firstSkillId;
          qs.selectedDifficultyId = firstDiffId;
          
          qs.options = [];
          for (final o in q.options) {
            qs.options.add(OptionState(
              text: o.optionText,
              isCorrect: o.isCorrect,
            ));
          }
          group.questions.add(qs);
        }
      }
      
      if (mounted) ToastHelper.show(context, 'Questions generated successfully!');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'System error, please try again later.');
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
    bool isValid = true;
    setState(() {
      for (int g = 0; g < _groups.length; g++) {
        final group = _groups[g];
        group.passageError = null;
        group.groupTypeError = null;

        if (group.isGroup && group.passageController.text.trim().isEmpty) {
          group.passageError = 'Passage text cannot be empty';
          isValid = false;
        }
        if (group.isGroup && group.selectedGroupTypeId == null) {
          group.groupTypeError = 'Please select a Group Type';
          isValid = false;
        }
        for (var i = 0; i < group.questions.length; i++) {
          final q = group.questions[i];
          q.skillError = null;
          q.difficultyError = null;
          q.questionTextError = null;
          q.optionsError = null;

          if (q.selectedSkillId == null) {
            q.skillError = 'Please select a Skill Type';
            isValid = false;
          }
          if (q.selectedDifficultyId == null) {
            q.difficultyError = 'Please select a Difficulty';
            isValid = false;
          }
          if (q.questionTextController.text.trim().isEmpty) {
            q.questionTextError = 'Question text cannot be empty';
            isValid = false;
          }
          if (!q.options.any((opt) => opt.isCorrect)) {
            q.optionsError = 'Must have at least one correct option';
            isValid = false;
          }
        }
      }
    });

    if (!isValid) return;

    setState(() => _isSaving = true);
    int successCount = 0;
    int errorCount = 0;

    try {
      final api = await _getApi();

      for (var group in _groups) {
        final payload = {
          if (widget.question != null) 'id': widget.question!.id,
          'categoryId': group.selectedGroupTypeId,
          'status': _status,
          'passageText': group.isGroup ? group.passageController.text : null,
          'subQuestions': group.questions.map((q) => {
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

        try {
          if (widget.question != null) {
            await api.updateCourseManagerQuestionGroup(widget.question!.id, payload, isGroup: widget.question!.isGroup);
          } else {
            await api.createCourseManagerQuestionGroup(payload);
          }
          successCount += group.questions.length;
        } catch (e) {
          errorCount += group.questions.length;
        }
      }

      if (mounted) {
        if (errorCount == 0) {
          ToastHelper.showSuccess(context, 'Saved $successCount questions successfully!');
          _goBack();
        } else {
          ToastHelper.showError(context, 'Saved $successCount questions, failed $errorCount questions.');
        }
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

    if (widget.isEmbedded) {
      return _isLoadingMetadata
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38C9A6)))
          : _buildMainContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.isCourseManager
          ? InternalAppHeader(isMobile: !(isDesktop), activeTab: '',)
          : null,
      drawer: !isDesktop 
          ? (widget.isCourseManager ? const Drawer(child: CourseManagerSidebar(currentRoute: 'question_bank')) : const Drawer(child: TrainerSidebar(activeIndex: 3)))
          : null,
      body: Row(
        children: [
          if (isDesktop) 
            SizedBox(
              width: widget.isCourseManager ? 240 : 250, 
              child: widget.isCourseManager ? const CourseManagerSidebar(currentRoute: 'question_bank') : const TrainerSidebar(activeIndex: 3)
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.isCourseManager) InternalAppHeader(isMobile: !isDesktop, showLogo: !isDesktop),
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
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < _groups.length; i++) ...[
                _buildGroupBlock(i),
                const SizedBox(height: 32),
              ],
              _buildAddButtons(),
              const SizedBox(height: 24),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButtons() {
    if (widget.isReadOnly || widget.isEdit) return const SizedBox();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _groups.add(QuestionGroupState(isGroup: true));
            });
          },
          icon: const Icon(Icons.add_box_outlined, size: 18),
          label: const Text('Add Question Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFF0F766E)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _groups.add(QuestionGroupState(isGroup: false));
            });
          },
          icon: const Icon(Icons.post_add_outlined, size: 18),
          label: const Text('Add Single Question'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFF0F766E)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupBlock(int groupIndex) {
    final group = _groups[groupIndex];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                group.isGroup ? 'Group ${groupIndex + 1}' : 'Single Question ${groupIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              if (!widget.isReadOnly)
                IconButton(
                  icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                  onPressed: () {
                    setState(() {
                      _groups.removeAt(groupIndex);
                    });
                  },
                ),
            ],
          ),
          const Divider(height: 32, color: Color(0xFFE2E8F0)),
          if (group.isGroup)
            MediaQuery.of(context).size.width < 700
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPassageEditor(group),
                      const SizedBox(height: 16),
                      _buildMetadataSection(group, groupIndex),
                      const SizedBox(height: 16),
                      _buildQuestionGroupUI(group),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 12,
                        child: Column(
                          children: [
                            _buildPassageEditor(group),
                            const SizedBox(height: 16),
                            _buildMetadataSection(group, groupIndex),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 10,
                        child: _buildQuestionGroupUI(group),
                      ),
                    ],
                  )
          else
            _buildSingleQuestionUI(group, groupIndex),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        OutlinedButton(
          onPressed: _goBack,
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

  Widget _buildPassageEditor(QuestionGroupState group) {
    final title = 'PASSAGE';
    final icon = Icons.article_outlined;
    final hint = 'Enter passage content here...';
    final controller = group.passageController;

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
              errorText: group.isGroup ? group.passageError : (group.questions.isNotEmpty ? group.questions[0].questionTextError : null),
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

  Widget _buildMetadataSection(QuestionGroupState group, int groupIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (group.isGroup) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('GROUP TYPE'),
                _buildDropdown(
                  value: group.selectedGroupTypeId,
                  items: _groupTypes,
                  onChanged: widget.isReadOnly ? null : (val) => setState(() => group.selectedGroupTypeId = val),
                  displayKey: 'paramValue',
                  allowNone: true,
                  errorText: group.groupTypeError,
                ),
              ],
            ),
          ],
          if (group.isGroup && !widget.isReadOnly) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Number of Questions (AI Generate)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                            if (group.aiQuantity > 2) group.aiQuantity--;
                          });
                        },
                      ),
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '${group.aiQuantity}',
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
                            if (group.aiQuantity < 10) group.aiQuantity++;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (group.isGroup && !widget.isReadOnly) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isGeneratingByAi || (group.isGroup && group.selectedGroupTypeId == null))
                    ? null
                    : () => _handleGenerateByAIForGroup(group),
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
    String? errorText,
  }) {
    final bool valueExists = value == null || items.any((item) => item['id'] == value);
    final int? safeValue = valueExists ? value : null;

    Widget dropdownWidget = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: errorText != null ? Colors.red : const Color(0xFFE2E8F0),
        ),
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
    
    if (errorText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dropdownWidget,
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      );
    }
    
    return dropdownWidget;
  }

  Widget _buildQuestionGroupUI(QuestionGroupState group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ANSWER DETAILS'),
        for (var i = 0; i < group.questions.length; i++) ...[
          _buildQuestionCard(group, i),
          const SizedBox(height: 12),
        ],
        if (!widget.isReadOnly)
          InkWell(
            onTap: () {
              setState(() {
                final newQ = QuestionState();
                if (_skills.isNotEmpty) newQ.selectedSkillId = _skills.first['id'] as int;
                if (_difficulties.isNotEmpty) newQ.selectedDifficultyId = _difficulties.first['id'] as int;
                group.questions.add(newQ);
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

  Widget _buildSingleQuestionUI(QuestionGroupState group, int groupIndex) {
    return _buildQuestionCard(group, 0, showTitle: false, showQuestionText: true);
  }

  Widget _buildQuestionCard(QuestionGroupState group, int index, {bool showTitle = true, bool showQuestionText = true}) {
    final qState = group.questions[index];
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
                  if (group.questions.length > 1 && !widget.isReadOnly)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          group.questions.removeAt(index);
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
                  Builder(builder: (context) {
                    final skillField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('SKILL TYPE'),
                        _buildDropdown(
                          value: qState.selectedSkillId,
                          items: _skills,
                          onChanged: widget.isReadOnly ? null : (val) => setState(() => qState.selectedSkillId = val),
                          displayKey: 'paramValue',
                          errorText: qState.skillError,
                        ),
                      ],
                    );
                    final difficultyField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('DIFFICULTY'),
                        _buildDropdown(
                          value: qState.selectedDifficultyId,
                          items: _difficulties,
                          onChanged: widget.isReadOnly ? null : (val) => setState(() => qState.selectedDifficultyId = val),
                          displayKey: 'paramValue',
                          errorText: qState.difficultyError,
                        ),
                      ],
                    );
                    if (MediaQuery.of(context).size.width < 420) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          skillField,
                          const SizedBox(height: 16),
                          difficultyField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: skillField),
                        const SizedBox(width: 16),
                        Expanded(child: difficultyField),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  if (!group.isGroup && !widget.isReadOnly) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingByAi
                            ? null
                            : () => _handleGenerateByAIForGroup(group),
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
                    const SizedBox(height: 16),
                  ],
                if (showQuestionText) ...[
                  _buildLabel('QUESTION'),
                  TextField(
                    controller: qState.questionTextController,
                    readOnly: widget.isReadOnly,
                    decoration: InputDecoration(
                      hintText: 'Enter question text...',
                      errorText: qState.questionTextError,
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
                if (qState.optionsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      qState.optionsError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
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
}
