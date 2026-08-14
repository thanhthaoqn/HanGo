import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../utils/config.dart';
import '../../../domain/model/trainer_ai_exam_models.dart';

import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../widgets/trainer/trainer_sidebar.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../../services/hango_api.dart';
import '../../../data/services/course_manager_api.dart';
import 'edit_exam_metadata_dialog.dart';

class OptionState {
  TextEditingController textController = TextEditingController();
  bool isCorrect;
  OptionState({String text = '', this.isCorrect = false}) {
    textController.text = text;
  }
}

class QuestionState {
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

class QuestionBlockState {
  bool isQuestionGroup = true;
  bool isGenerated = false;
  int? selectedSkillId;
  int? selectedGroupTypeId;
  int? selectedDifficultyId;
  String? passageError;
  String? groupTypeError;
  TextEditingController passageController = TextEditingController();
  List<QuestionState> questions = [QuestionState()];
}

class CourseManagerEditExamPage extends StatefulWidget {
  final int examId;
  final String examTitle;
  final int examExpectedCount;
  final bool isReadOnly;
  final String? courseManagerActionStatus;
  final bool isCourseManager;
  final TrainerAiExamGenerateResponse? initialAiData;
  final bool isEmbedded;
  final VoidCallback? onBack;
  final Map<String, dynamic>? initialExamData;

  const CourseManagerEditExamPage({
    Key? key,
    required this.examId,
    required this.examTitle,
    this.examExpectedCount = 10,
    this.isReadOnly = false,
    this.courseManagerActionStatus,
    this.isCourseManager = true,
    this.initialAiData,
    this.isEmbedded = false,
    this.onBack,
    this.initialExamData,
  }) : super(key: key);

  @override
  State<CourseManagerEditExamPage> createState() =>
      _CourseManagerEditExamPageState();
}

class _CourseManagerEditExamPageState extends State<CourseManagerEditExamPage> {
  final _authService = AuthService();

  bool _isLoadingMetadata = true;
  bool _isSaving = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _groupTypes = [];
  List<Map<String, dynamic>> _difficulties = [];

  final List<QuestionBlockState> _blocks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _goBack() {
    if (widget.isEmbedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
  }

  void _editBasicInfo() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditExamMetadataDialog(
        initialData: widget.initialExamData!,
        onSave: (newData) async {
          if (widget.isCourseManager) {
            await CourseManagerApi().updateExamInfo(widget.examId, newData);
          } else {
            final token = await _authService.getToken();
            await HangoApi(
              baseUrl: EnvConfig.apiBaseUrl,
              token: token,
            ).updateExamInfo(widget.examId, newData);
          }
        },
      ),
    );

    if (result == true) {
      ToastHelper.show(context, 'Exam metadata updated successfully');
      if (widget.onBack != null) {
        widget.onBack!(); // Go back to exam list to see updated data and possibly new status
      }
    }
  }

  Future<void> _loadData() async {
    await _loadMetadata();

    if (widget.initialAiData != null) {
      _loadDataFromAi(widget.initialAiData!);
    } else {
      await _loadQuestions();
    }

    if (mounted) {
      setState(() {
        _isLoadingMetadata = false;
      });
    }
  }

  void _loadDataFromAi(TrainerAiExamGenerateResponse aiData) {
    _blocks.clear();
    for (var aiBlock in aiData.blocks) {
      final block = QuestionBlockState();
      block.isGenerated = true;
      block.isQuestionGroup = aiBlock.isQuestionGroup;
      block.passageController.text = aiBlock.passageText;
      block.selectedGroupTypeId = aiBlock.categoryId; // Mapping groupType to categoryId
      block.selectedSkillId = aiBlock.skillParamId;
      block.selectedDifficultyId = aiBlock.difficultyId;
      block.questions = aiBlock.questions.map((aiQ) {
        final q = QuestionState();
        q.questionTextController.text = aiQ.questionText;
        q.explanationController.text = aiQ.explanation;
        q.selectedSkillId = aiBlock.skillParamId; // Use block\'s skill
        q.selectedDifficultyId = aiQ.difficultyId;
        q.options = aiQ.options
            .map(
              (aiOpt) => OptionState(
                text: aiOpt.optionText,
                isCorrect: aiOpt.isCorrect,
              ),
            )
            .toList();
        // Ensure 4 options
        while (q.options.length < 4) {
          q.options.add(OptionState());
        }
        return q;
      }).toList();
      _blocks.add(block);
    }
  }

  Future<void> _updateExamStatus(String newStatus) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final String apiBaseUrl = EnvConfig.v1BaseUrl;

      final response = await http.patch(
        Uri.parse('$apiBaseUrl/trainer/exams/${widget.examId}/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ToastHelper.show(context, 'Thành công!');
          _goBack();
        }
      } else {
        if (mounted) {
          ToastHelper.show(context, 'Lỗi cập nhật', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showActionDialog(
    String actionName,
    String newStatus,
    Color confirmColor,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '$actionName Exam',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to $actionName this exam?',
            style: const TextStyle(fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateExamStatus(newStatus);
              },
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRejectDialog() {
    bool rejectGeneral = false;
    final TextEditingController rejectGeneralCtrl = TextEditingController();

    bool rejectQuestions = false;
    final TextEditingController rejectQuestionsCtrl = TextEditingController();

    bool rejectOptions = false;
    final TextEditingController rejectOptionsCtrl = TextEditingController();

    bool rejectOther = false;
    final TextEditingController rejectOtherCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setState) {
            return AlertDialog(
              title: const Text(
                'Rejection Checklist',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check the issues below and provide details for the Trainer:',
                      style: TextStyle(fontFamily: 'Outfit', color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 12),

                    // General Info Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('General Info (Title, Requirements)', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                      value: rejectGeneral,
                      activeColor: const Color(0xFFEF4444),
                      onChanged: (val) => setState(() => rejectGeneral = val ?? false),
                    ),
                    if (rejectGeneral)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: TextField(
                          controller: rejectGeneralCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'E.g., Title is unclear...',
                            filled: true,
                            fillColor: const Color(0xFFFEF2F2),
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                          ),
                        ),
                      ),

                    // Questions & Passages Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Questions & Passages (Content, typos)', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                      value: rejectQuestions,
                      activeColor: const Color(0xFFEF4444),
                      onChanged: (val) => setState(() => rejectQuestions = val ?? false),
                    ),
                    if (rejectQuestions)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: TextField(
                          controller: rejectQuestionsCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'Specify issues with questions or passages...',
                            filled: true,
                            fillColor: const Color(0xFFFEF2F2),
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                          ),
                        ),
                      ),

                    // Answers & Options Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Answers & Options (Accuracy)', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                      value: rejectOptions,
                      activeColor: const Color(0xFFEF4444),
                      onChanged: (val) => setState(() => rejectOptions = val ?? false),
                    ),
                    if (rejectOptions)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: TextField(
                          controller: rejectOptionsCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'E.g., Wrong correct answer marked...',
                            filled: true,
                            fillColor: const Color(0xFFFEF2F2),
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                          ),
                        ),
                      ),

                    // Other Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Other Issues', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w500)),
                      value: rejectOther,
                      activeColor: const Color(0xFFEF4444),
                      onChanged: (val) => setState(() => rejectOther = val ?? false),
                    ),
                    if (rejectOther)
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: TextField(
                          controller: rejectOtherCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                          decoration: InputDecoration(
                            hintText: 'Enter other reasons...',
                            filled: true,
                            fillColor: const Color(0xFFFEF2F2),
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF4444))),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(innerContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!rejectGeneral && !rejectQuestions && !rejectOptions && !rejectOther) {
                      ToastHelper.showError(context, 'Please check at least one issue.');
                      return;
                    }

                    List<String> reasons = [];
                    
                    if (rejectGeneral) {
                      String detail = rejectGeneralCtrl.text.trim();
                      if (detail.isEmpty) detail = "Need to review general information.";
                      reasons.add("- [x] **General Info (Title, Requirements):**\n  $detail");
                    }
                    
                    if (rejectQuestions) {
                      String detail = rejectQuestionsCtrl.text.trim();
                      if (detail.isEmpty) detail = "Issues found in questions or passages.";
                      reasons.add("- [x] **Questions & Passages (Content, typos):**\n  $detail");
                    }
                    
                    if (rejectOptions) {
                      String detail = rejectOptionsCtrl.text.trim();
                      if (detail.isEmpty) detail = "Issues found in answers or options.";
                      reasons.add("- [x] **Answers & Options (Accuracy):**\n  $detail");
                    }
                    
                    if (rejectOther) {
                      String detail = rejectOtherCtrl.text.trim();
                      if (detail.isNotEmpty) {
                        reasons.add("- [x] **Other Issues:**\n  $detail");
                      }
                    }
                    
                    String finalReason = reasons.join("\n\n");
                    
                    Navigator.pop(innerContext);
                    
                    try {
                      await CourseManagerApi().rejectExam(
                        widget.examId,
                        reason: finalReason,
                      );
                      if (mounted) {
                        ToastHelper.show(context, 'Exam rejected successfully!');
                        _goBack(); // Go back to list
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastHelper.show(
                          context,
                          'Error rejecting exam: $e',
                          isError: true,
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _publishExamAsManager() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Approve Exam',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        content: Text(
          'Are you sure you want to approve and publish the exam "${widget.examTitle}"?',
          style: const TextStyle(
            color: Color(0xFF475569),
            fontFamily: 'Outfit',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Approve',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CourseManagerApi().publishExam(widget.examId);
      if (mounted) {
        ToastHelper.show(context, 'Exam approved and published successfully!');
        _goBack(); // Go back to list
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Error approving exam: $e', isError: true);
      }
    }
  }

  void _addBlockListeners(QuestionBlockState b) {
    b.passageController.addListener(_updateProgress);
    for (var q in b.questions) {
      _addQuestionListeners(q);
    }
  }

  void _addQuestionListeners(QuestionState q) {
    q.questionTextController.addListener(_updateProgress);
    for (var o in q.options) {
      o.textController.addListener(_updateProgress);
    }
  }

  void _updateProgress() {
    setState(() {}); // Trigger UI update for progress
  }

  int get _completedQuestions {
    int count = 0;
    for (var block in _blocks) {
      if (!block.isQuestionGroup) {
        bool isComplete =
            block.questions[0].questionTextController.text.trim().isNotEmpty &&
            block.questions[0].options.any(
              (o) => o.textController.text.trim().isNotEmpty,
            );
        if (isComplete) count++;
      } else {
        if (block.passageController.text.trim().isNotEmpty) {
          for (var q in block.questions) {
            if (q.questionTextController.text.trim().isNotEmpty &&
                q.options.any((o) => o.textController.text.trim().isNotEmpty)) {
              count++;
            }
          }
        }
      }
    }
    return count;
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

      setState(() {
        _skills = skills;
        _difficulties = difficulties;
        _groupTypes = groupTypes;
      });
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Failed to load metadata: $e', isError: true);
      }
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final api = await _getApi();
      final response = await api.getExamQuestions(widget.examId);

      final blocksData = response['blocks'] as List?;
      if (blocksData == null || blocksData.isEmpty) {
        final initialBlock = QuestionBlockState();
        _blocks.add(initialBlock);
        _addBlockListeners(initialBlock);
      } else {
        for (var blockData in blocksData) {
          final block = QuestionBlockState();
          block.isGenerated = true; // Disable toggle for existing blocks
          block.selectedGroupTypeId = blockData['categoryId'];

          if (blockData['passageText'] != null &&
              blockData['passageText'].toString().isNotEmpty) {
            block.isQuestionGroup = true;
            block.passageController.text = blockData['passageText'];
          } else {
            block.isQuestionGroup = false;
          }

          final subQData = blockData['subQuestions'] as List?;
          if (subQData != null && subQData.isNotEmpty) {
            block.questions.clear(); // Clear default empty question
            for (var qData in subQData) {
              final qState = QuestionState();
              qState.questionTextController.text = qData['questionText'] ?? '';
              qState.explanationController.text = qData['explanation'] ?? '';
              qState.selectedSkillId =
                  qData['skillParamId'] ?? blockData['skillParamId'];
              qState.selectedDifficultyId =
                  qData['difficultyId'] ?? blockData['difficultyId'];

              final optsData = qData['options'] as List?;
              if (optsData != null && optsData.isNotEmpty) {
                qState.options.clear(); // Clear default options
                for (var oData in optsData) {
                  qState.options.add(
                    OptionState(
                      text: oData['optionText'] ?? '',
                      isCorrect: oData['isCorrect'] ?? false,
                    ),
                  );
                }
                while (qState.options.length < 4) {
                  qState.options.add(OptionState(text: '', isCorrect: false));
                }
              }
              block.questions.add(qState);
            }
          }
          _blocks.add(block);
          _addBlockListeners(block);
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(
          context,
          'Failed to load exam questions: $e',
          isError: true,
        );
        final initialBlock = QuestionBlockState();
        _blocks.add(initialBlock);
        _addBlockListeners(initialBlock);
      }
    }
  }

  bool _validateBlocks() {
    bool isValid = true;
    setState(() {
      for (var i = 0; i < _blocks.length; i++) {
        final block = _blocks[i];
        block.passageError = null;
        block.groupTypeError = null;

        if (block.isQuestionGroup &&
            block.passageController.text.trim().isEmpty) {
          block.passageError = 'Passage text cannot be empty';
          isValid = false;
        }

        for (var j = 0; j < block.questions.length; j++) {
          final q = block.questions[j];
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
    return isValid;
  }

  Map<String, dynamic> _buildBlocksPayload() {
    return {
      'blocks': _blocks
          .map(
            (block) => {
              'categoryId': block.selectedGroupTypeId,
              'skillParamId': block.questions.isNotEmpty
                  ? block.questions.first.selectedSkillId
                  : null,
              'difficultyId': block.questions.isNotEmpty
                  ? block.questions.first.selectedDifficultyId
                  : null,
              'passageText': block.isQuestionGroup
                  ? block.passageController.text
                  : null,
              'subQuestions': block.questions
                  .map(
                    (q) => {
                      'questionText': q.questionTextController.text,
                      'explanation': q.explanationController.text,
                      'skillParamId': q.selectedSkillId,
                      'difficultyId': q.selectedDifficultyId,
                      'options': q.options
                          .map(
                            (o) => {
                              'optionText': o.textController.text,
                              'isCorrect': o.isCorrect,
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  Future<void> _handleSave() async {
    if (!_validateBlocks()) return;

    setState(() => _isSaving = true);
    try {
      final api = await _getApi();
      await api.saveExamQuestions(widget.examId, _buildBlocksPayload());

      if (mounted) {
        ToastHelper.show(context, 'All questions saved successfully!');
        _goBack();
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

  Future<void> _handleSubmitForReview() async {
    final isCm = widget.isCourseManager;

    if (isCm) {
      final selectedStatus = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.publish, color: Color(0xFF6366F1), size: 24),
              const SizedBox(width: 10),
              const Text(
                'Submit Exam',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to publish the exam "${widget.examTitle}"?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'PUBLISHED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38C9A6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Publish',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (selectedStatus == null) return;

      setState(() => _isSubmitting = true);
      try {
        final api = await _getApi();
        await api.updateExamStatus(widget.examId, selectedStatus);
        if (mounted) {
          ToastHelper.show(
            context,
            'Exam status updated to $selectedStatus successfully!',
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.show(
            context,
            'Failed to update status: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    } else {
      // Trainer flow
      if (!_validateBlocks()) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.send_rounded,
                color: Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'Save & Submit for Review',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save the current questions and submit the exam "${widget.examTitle}" for the Course Manager\'s review?',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After submission, the exam will wait for the Course Manager\'s review before being published.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6366F1),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Save & Submit',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isSubmitting = true);
      try {
        final api = await _getApi();
        // Always persist the latest question edits before flipping the
        // status to SUBMITTED, so a submitted exam can never end up with
        // stale or missing questions.
        await api.saveExamQuestions(widget.examId, _buildBlocksPayload());
        await api.updateExamStatus(widget.examId, 'SUBMITTED');
        if (mounted) {
          ToastHelper.show(
            context,
            'Exam saved and submitted for review successfully!',
          );
          _goBack();
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.show(
            context,
            'Failed to save & submit exam: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isEmbedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF4B5563)),
                    onPressed: widget.onBack,
                  ),
                if (widget.onBack != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.examTitle} (${widget.isReadOnly ? 'View Mode' : 'Edit Mode'})',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.isReadOnly && widget.initialExamData != null)
                  ElevatedButton.icon(
                    onPressed: _editBasicInfo,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Basic Info'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF20B486),
                      side: const BorderSide(color: Color(0xFF20B486)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _isLoadingMetadata
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF38C9A6),
                  ),
                )
              : _buildMainContent(),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !isDesktop),
      drawer: !isDesktop
          ? Drawer(
              child: widget.isCourseManager
                  ? const CourseManagerSidebar(currentRoute: 'exams')
                  : const TrainerSidebar(activeIndex: 2),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: widget.isCourseManager ? 240 : 260,
              child: widget.isCourseManager
                  ? const CourseManagerSidebar(currentRoute: 'exams')
                  : const TrainerSidebar(activeIndex: 2),
            ),
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Scrollable Content
        // Lazily built with slivers: a large imported exam can have dozens
        // of blocks, each with several TextEditingControllers wired to a
        // page-wide setState (see _updateProgress). Eagerly building every
        // block in a Column meant a full-page relayout on every keystroke
        // in any field, causing severe input lag; SliverList only rebuilds
        // the blocks currently on/near screen.
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => IgnorePointer(
                      ignoring: widget.isReadOnly,
                      child: _buildQuestionBlock(index),
                    ),
                    childCount: _blocks.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: IgnorePointer(
                    ignoring: widget.isReadOnly,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        if (!widget.isReadOnly)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  final newBlock = QuestionBlockState();
                                  _blocks.add(newBlock);
                                  _addBlockListeners(newBlock);
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Add More Question',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _goBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(
                        (!widget.isReadOnly ||
                                (widget.isCourseManager &&
                                    widget.courseManagerActionStatus ==
                                        'SUBMITTED'))
                            ? 'Cancel'
                            : 'Back',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (!widget.isReadOnly) ...[
                      if (_completedQuestions >= widget.examExpectedCount &&
                          widget.examExpectedCount > 0) ...[
                        ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _handleSubmitForReview,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                          label: Text(
                            widget.isCourseManager
                                ? 'Submit'
                                : 'Save & Submit for Review',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38C9A6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Draft',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                      ),
                    ] else if (widget.courseManagerActionStatus != null) ...[
                      if (widget.courseManagerActionStatus ==
                              'PENDING_APPROVAL' ||
                          widget.courseManagerActionStatus == 'PENDING' ||
                          widget.courseManagerActionStatus == 'SUBMITTED') ...[
                        ElevatedButton.icon(
                          onPressed: _showRejectDialog,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _publishExamAsManager,
                          icon: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Approve',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38C9A6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                      if (widget.courseManagerActionStatus == 'PUBLISHED') ...[
                        ElevatedButton.icon(
                          onPressed: () => _showActionDialog(
                            'Hide',
                            'HIDDEN',
                            Colors.orange,
                          ),
                          icon: const Icon(
                            Icons.visibility_off,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Hide Exam',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                      if (widget.courseManagerActionStatus == 'HIDDEN') ...[
                        ElevatedButton.icon(
                          onPressed: () => _showActionDialog(
                            'Publish',
                            'PUBLISHED',
                            const Color(0xFF38C9A6),
                          ),
                          icon: const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Publish Exam',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38C9A6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                  ),
              ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBlock(int blockIndex) {
    final block = _blocks[blockIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${blockIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              if (_blocks.length > 1) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _blocks.removeAt(blockIndex);
                    });
                  },
                ),
              ],
              const Spacer(),
            ],
          ),
          const SizedBox(height: 24),
          MediaQuery.of(context).size.width < 700
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLeftColumn(blockIndex),
                    const SizedBox(height: 16),
                    _buildRightColumn(blockIndex),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 12, child: _buildLeftColumn(blockIndex)),
                    const SizedBox(width: 16),
                    Expanded(flex: 10, child: _buildRightColumn(blockIndex)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(int blockIndex) {
    return Column(
      children: [
        _buildPassageEditor(blockIndex),
        const SizedBox(height: 16),
        _buildMetadataSection(blockIndex),
      ],
    );
  }

  Widget _buildRightColumn(int blockIndex) {
    final block = _blocks[blockIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionTypeToggle(blockIndex),
        const SizedBox(height: 16),
        if (block.isQuestionGroup)
          _buildQuestionGroupUI(blockIndex)
        else
          _buildSingleQuestionUI(blockIndex),
      ],
    );
  }

  Widget _buildPassageEditor(int blockIndex) {
    final block = _blocks[blockIndex];
    final title = block.isQuestionGroup ? 'PASSAGE' : 'QUESTION';
    final icon = block.isQuestionGroup
        ? Icons.article_outlined
        : Icons.help_outline;
    final hint = block.isQuestionGroup
        ? 'Enter passage content here...'
        : 'Enter question text here...';
    final controller = block.isQuestionGroup
        ? block.passageController
        : block.questions[0].questionTextController;

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
            decoration: InputDecoration(
              hintText: hint,
              errorText: block.isQuestionGroup ? block.passageError : (block.questions.isNotEmpty ? block.questions[0].questionTextError : null),
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
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(int blockIndex) {
    final block = _blocks[blockIndex];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (!block.isQuestionGroup) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('SKILL TYPE'),
                      _buildDropdown(
                        value: block.questions.isNotEmpty
                            ? block.questions[0].selectedSkillId
                            : null,
                        items: _skills,
                        onChanged: (val) {
                          if (block.questions.isNotEmpty) {
                            setState(
                              () => block.questions[0].selectedSkillId = val,
                            );
                          }
                        },
                        displayKey: 'paramValue',
                        errorText: block.questions.isNotEmpty ? block.questions[0].skillError : null,
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
                        value: block.questions.isNotEmpty
                            ? block.questions[0].selectedDifficultyId
                            : null,
                        items: _difficulties,
                        onChanged: (val) {
                          if (block.questions.isNotEmpty) {
                            setState(
                              () =>
                                  block.questions[0].selectedDifficultyId = val,
                            );
                          }
                        },
                        displayKey: 'paramValue',
                        errorText: block.questions.isNotEmpty ? block.questions[0].difficultyError : null,
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
                        value: block.selectedGroupTypeId,
                        items: _groupTypes,
                        onChanged: (val) =>
                            setState(() => block.selectedGroupTypeId = val),
                        displayKey: 'paramValue',
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
    required Function(int?) onChanged,
    required String displayKey,
    String? errorText,
  }) {
    // Fix Dropdown crash: verify if the value actually exists in the items list
    bool valueExists =
        value != null && items.any((item) => (item['id'] as int) == value);
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
        child: DropdownButton<int>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          items: items.map((item) {
            return DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(
                item[displayKey]?.toString() ?? '',
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              ),
            );
          }).toList(),
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

  Widget _buildQuestionTypeToggle(int blockIndex) {
    final block = _blocks[blockIndex];
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
                isActive: block.isQuestionGroup,
                onTap: block.isGenerated
                    ? null
                    : () {
                        setState(() {
                          block.isQuestionGroup = true;
                        });
                      },
              ),
              const SizedBox(width: 12),
              _buildToggleButton(
                title: 'Single Question',
                icon: Icons.edit_note_outlined,
                isActive: !block.isQuestionGroup,
                onTap: block.isGenerated
                    ? null
                    : () {
                        setState(() {
                          block.isQuestionGroup = false;
                          if (block.questions.length > 1) {
                            block.questions = [
                              block.questions.first,
                            ]; // Keep only first question
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

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isActive,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE0E7FF) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: onTap == null 
                    ? const Color(0xFF94A3B8)
                    : (isActive ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: onTap == null 
                      ? const Color(0xFF94A3B8)
                      : (isActive ? const Color(0xFF6366F1) : const Color(0xFF64748B)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionGroupUI(int blockIndex) {
    final block = _blocks[blockIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ANSWER DETAILS'),
        for (var i = 0; i < block.questions.length; i++) ...[
          _buildQuestionCard(blockIndex, i),
          const SizedBox(height: 12),
        ],
        // Add Answer Set Button
        InkWell(
          onTap: () {
            setState(() {
              final newQuestion = QuestionState();
              block.questions.add(newQuestion);
              _addQuestionListeners(newQuestion);
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
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleQuestionUI(int blockIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('ANSWER DETAILS'),
        _buildQuestionCard(
          blockIndex,
          0,
          showTitle: false,
          showQuestionText: false,
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    int blockIndex,
    int questionIndex, {
    bool showTitle = true,
    bool showQuestionText = true,
  }) {
    final block = _blocks[blockIndex];
    final qState = block.questions[questionIndex];
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
                    'Question ${questionIndex + 1}',
                    style: const TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (block.questions.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          block.questions.removeAt(questionIndex);
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
                if (block.isQuestionGroup) ...[
                  Builder(builder: (context) {
                    final skillField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('SKILL TYPE'),
                        _buildDropdown(
                          value: qState.selectedSkillId,
                          items: _skills,
                          onChanged: (val) =>
                              setState(() => qState.selectedSkillId = val),
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
                          onChanged: (val) => setState(
                            () => qState.selectedDifficultyId = val,
                          ),
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
                ],
                if (showQuestionText) ...[
                  _buildLabel('QUESTION'),
                  TextField(
                    controller: qState.questionTextController,
                    decoration: InputDecoration(
                      hintText: 'Enter question text...',
                      errorText: qState.questionTextError,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildLabel('OPTIONS (Select correct answer)'),
                for (
                  var optIndex = 0;
                  optIndex < qState.options.length;
                  optIndex++
                ) ...[
                  _buildOptionRow(
                    blockIndex,
                    questionIndex,
                    optIndex,
                    letters[optIndex],
                  ),
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
                  decoration: const InputDecoration(
                    hintText: 'Add explanation...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(
    int blockIndex,
    int questionIndex,
    int optIndex,
    String letter,
  ) {
    final block = _blocks[blockIndex];
    final qState = block.questions[questionIndex];
    final option = qState.options[optIndex];

    return Row(
      children: [
        InkWell(
          onTap: () {
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
              border: Border.all(
                color: option.isCorrect
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF94A3B8),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                color: option.isCorrect
                    ? Colors.white
                    : const Color(0xFF475569),
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
            decoration: InputDecoration(
              hintText: 'Option $letter',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: option.isCorrect
                      ? const Color(0xFF38C9A6)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: option.isCorrect
                      ? const Color(0xFF38C9A6)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              filled: option.isCorrect,
              fillColor: option.isCorrect
                  ? const Color(0xFFE2F9F3)
                  : Colors.white,
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
