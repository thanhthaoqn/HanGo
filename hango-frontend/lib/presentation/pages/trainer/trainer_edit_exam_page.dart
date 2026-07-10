import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import '../login_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_exams_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import '../../../services/hango_api.dart';

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
  int? selectedSkillId;
  int? selectedGroupTypeId;
  int? selectedDifficultyId;
  TextEditingController passageController = TextEditingController();
  List<QuestionState> questions = [QuestionState()];
}

class TrainerEditExamPage extends StatefulWidget {
  final int examId;
  final String examTitle;
  final int examExpectedCount;
  const TrainerEditExamPage({Key? key, required this.examId, required this.examTitle, this.examExpectedCount = 10}) : super(key: key);

  @override
  State<TrainerEditExamPage> createState() => _TrainerEditExamPageState();
}

class _TrainerEditExamPageState extends State<TrainerEditExamPage> {
  final _authService = AuthService();
  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

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
    _loadTrainerInfo();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await _loadMetadata();
    await _loadQuestions();
    if (mounted) {
      setState(() {
        _isLoadingMetadata = false;
      });
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
        bool isComplete = block.questions[0].questionTextController.text.trim().isNotEmpty && 
                          block.questions[0].options.any((o) => o.textController.text.trim().isNotEmpty);
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
    final String apiBaseUrl = kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
    return HangoApi(baseUrl: apiBaseUrl, token: token);
  }

  Future<void> _loadMetadata() async {
    try {
      final api = await _getApi();
      final skills = await api.getSystemParameters('SKILL_TYPE');
      final difficulties = await api.getSystemParameters('DIFFICULTY');
      final groupTypes = await api.getQuestionCategories();

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
          block.selectedGroupTypeId = blockData['categoryId'];
          block.selectedSkillId = blockData['skillParamId'];
          block.selectedDifficultyId = blockData['difficultyId'];
          
          if (blockData['passageText'] != null && blockData['passageText'].toString().isNotEmpty) {
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
              
              final optsData = qData['options'] as List?;
              if (optsData != null && optsData.isNotEmpty) {
                qState.options.clear(); // Clear default options
                for (var oData in optsData) {
                  qState.options.add(OptionState(
                    text: oData['optionText'] ?? '',
                    isCorrect: oData['isCorrect'] ?? false,
                  ));
                }
                while(qState.options.length < 4) {
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
        ToastHelper.show(context, 'Failed to load exam questions: $e', isError: true);
        final initialBlock = QuestionBlockState();
        _blocks.add(initialBlock);
        _addBlockListeners(initialBlock);
      }
    }
  }

  Future<void> _handleSave() async {
    // Basic validation
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];

      if (block.selectedGroupTypeId == null) {
        ToastHelper.show(context, 'Khối ${i + 1}: Vui lòng chọn Danh mục (Category).', isError: true);
        return;
      }
      if (block.selectedSkillId == null) {
        ToastHelper.show(context, 'Khối ${i + 1}: Vui lòng chọn Kỹ năng (Skill).', isError: true);
        return;
      }
      if (block.selectedDifficultyId == null) {
        ToastHelper.show(context, 'Khối ${i + 1}: Vui lòng chọn Độ khó (Difficulty).', isError: true);
        return;
      }
      if (block.isQuestionGroup && block.passageController.text.trim().isEmpty) {
        ToastHelper.show(context, 'Khối ${i + 1}: Nội dung đoạn văn không được để trống.', isError: true);
        return;
      }
      for (var j = 0; j < block.questions.length; j++) {
        final q = block.questions[j];
        if (q.questionTextController.text.trim().isEmpty) {
          ToastHelper.show(context, 'Khối ${i + 1} - Câu ${j + 1}: Nội dung câu hỏi không được để trống.', isError: true);
          return;
        }
        if (!q.options.any((opt) => opt.isCorrect)) {
          ToastHelper.show(context, 'Khối ${i + 1} - Câu ${j + 1}: Phải có ít nhất 1 đáp án đúng.', isError: true);
          return;
        }
      }
    }

    setState(() => _isSaving = true);
    try {
      final api = await _getApi();
      
      final payload = {
        'blocks': _blocks.map((block) => {
          'categoryId': block.selectedGroupTypeId,
          'skillParamId': block.selectedSkillId,
          'difficultyId': block.selectedDifficultyId,
          'passageText': block.isQuestionGroup ? block.passageController.text : null,
          'subQuestions': block.questions.map((q) => {
            'questionText': q.questionTextController.text,
            'explanation': q.explanationController.text,
            'options': q.options.map((o) => {
              'optionText': o.textController.text,
              'isCorrect': o.isCorrect,
            }).toList()
          }).toList(),
        }).toList(),
      };
      
      await api.saveExamQuestions(widget.examId, payload);

      if (mounted) {
        ToastHelper.show(context, 'All questions saved successfully!');
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

  Future<void> _handleSubmitForReview() async {
    // Hiện popup xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.send_rounded, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 10),
            Text('Submit for Review', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to submit the exam "${widget.examTitle}" for review?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF475569), fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After submission, the exam will wait for the Course Manager\'s review before being published.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontFamily: 'Outfit'),
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
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Confirm Submission', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final api = await _getApi();
      await api.updateExamStatus(widget.examId, 'SUBMITTED');
      if (mounted) {
        ToastHelper.show(context, 'Exam submitted for review successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Failed to submit: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
    return Column(
      children: [
        // Sticky Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Text(
                '${widget.examTitle} (Edit mode)',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'Outfit',
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'OVERALL COMPLETION PROGRESS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 120,
                        height: 6,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(3)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widget.examExpectedCount > 0
                              ? (_completedQuestions / widget.examExpectedCount.toDouble()).clamp(0.0, 1.0)
                              : 0.0,
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFF38C9A6), borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.examExpectedCount > 0 ? ((_completedQuestions / widget.examExpectedCount.toDouble()) * 100).toInt().clamp(0, 100) : 0}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Column(
            children: [
              for (var i = 0; i < _blocks.length; i++)
                _buildQuestionBlock(i),
              const SizedBox(height: 16),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Add More Question', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
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
                  const SizedBox(width: 16),
                  // Hiện nút Submit for Review khi đã nhập đủ số câu
                  if (_completedQuestions >= widget.examExpectedCount && widget.examExpectedCount > 0) ...[
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleSubmitForReview,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      label: const Text('Submit for Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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
                        : const Text('Save Draft', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
              SizedBox(
                width: 140,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    ToastHelper.show(context, 'Not implemented yet!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38C9A6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 16),
                      SizedBox(width: 4),
                      Text('Choose Question\nfrom Question Bank', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                      ToastHelper.show(context, 'Not implemented yet!');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 16),
                      SizedBox(width: 4),
                      Text('Import\nfrom Excel', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 12,
                child: _buildLeftColumn(blockIndex),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 10,
                child: _buildRightColumn(blockIndex),
              ),
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
        if (block.isQuestionGroup) _buildQuestionGroupUI(blockIndex) else _buildSingleQuestionUI(blockIndex),
      ],
    );
  }

  Widget _buildPassageEditor(int blockIndex) {
    final block = _blocks[blockIndex];
    final title = block.isQuestionGroup ? 'PASSAGE' : 'QUESTION';
    final icon = block.isQuestionGroup ? Icons.article_outlined : Icons.help_outline;
    final hint = block.isQuestionGroup ? 'Enter passage content here...' : 'Enter question text here...';
    final controller = block.isQuestionGroup ? block.passageController : block.questions[0].questionTextController;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('SKILL TYPE'),
                    _buildDropdown(
                      value: block.selectedSkillId,
                      items: _skills,
                      onChanged: (val) => setState(() => block.selectedSkillId = val),
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
                      value: block.selectedGroupTypeId,
                      items: _groupTypes,
                      onChanged: (val) => setState(() => block.selectedGroupTypeId = val),
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
                      value: block.selectedDifficultyId,
                      items: _difficulties,
                      onChanged: (val) => setState(() => block.selectedDifficultyId = val),
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
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Draft', style: TextStyle(color: Color(0xFF475569), fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required int? value,
    required List<Map<String, dynamic>> items,
    required Function(int?) onChanged,
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
                onTap: () {
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
                onTap: () {
                  setState(() {
                    block.isQuestionGroup = false;
                    if (block.questions.length > 1) {
                      block.questions = [block.questions.first]; // Keep only first question
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
                  style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
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
        _buildQuestionCard(blockIndex, 0, showTitle: false, showQuestionText: false),
      ],
    );
  }

  Widget _buildQuestionCard(int blockIndex, int questionIndex, {bool showTitle = true, bool showQuestionText = true}) {
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
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
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
                if (showQuestionText) ...[
                  _buildLabel('QUESTION'),
                  TextField(
                    controller: qState.questionTextController,
                    decoration: const InputDecoration(
                      hintText: 'Enter question text...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildLabel('OPTIONS (Select correct answer)'),
                for (var optIndex = 0; optIndex < qState.options.length; optIndex++) ...[
                  _buildOptionRow(blockIndex, questionIndex, optIndex, letters[optIndex]),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                _buildLabel('EXPLANATION (Optional)'),
                TextField(
                  controller: qState.explanationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add explanation...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildOptionRow(int blockIndex, int questionIndex, int optIndex, String letter) {
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
              filled: option.isCorrect,
              fillColor: option.isCorrect ? const Color(0xFFE2F9F3) : Colors.white,
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
          _buildSidebarItem(Icons.assignment_outlined, 'Exam', isSelected: true, onTap: () {
             Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerExamsPage()),
            );
          }),
          _buildSidebarItem(Icons.folder_open_outlined, 'Question Bank', onTap: () {
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
            'Exam',
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
            'Edit Exam',
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
