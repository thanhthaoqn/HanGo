import 'package:flutter/material.dart';
import 'course_manager_edit_exam_page.dart';
import '../../../services/hango_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'package:flutter/foundation.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/config.dart';

class CourseManagerExamMatrixPage extends StatefulWidget {
  final VoidCallback onBack;
  final bool isCourseManager;
  final List<Map<String, dynamic>>? preloadedMatrices;
  final bool? isMatricesLoading;
  const CourseManagerExamMatrixPage({super.key, required this.onBack, this.isCourseManager = false, this.preloadedMatrices, this.isMatricesLoading});

  @override
  State<CourseManagerExamMatrixPage> createState() => _CourseManagerExamMatrixPageState();
}

class _CourseManagerExamMatrixPageState extends State<CourseManagerExamMatrixPage> {
  final _authService = AuthService();
  late HangoApi _api;
  List<Map<String, dynamic>> _matrices = [];
  bool _isLoading = true;
  String? _selectedMatrixId;

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedMatrices != null) {
      _matrices = widget.preloadedMatrices!;
      _isLoading = widget.isMatricesLoading ?? false;
      _initApiWithoutFetch();
    } else {
      _initApi();
    }
  }

  Future<void> _initApiWithoutFetch() async {
    final token = await _authService.getToken();
    _api = HangoApi(baseUrl: apiBaseUrl, token: token);
  }

  @override
  void didUpdateWidget(covariant CourseManagerExamMatrixPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preloadedMatrices != null && widget.preloadedMatrices != oldWidget.preloadedMatrices) {
      setState(() {
        _matrices = widget.preloadedMatrices!;
        _isLoading = widget.isMatricesLoading ?? false;
      });
    }
    if (widget.isMatricesLoading != null && widget.isMatricesLoading != oldWidget.isMatricesLoading) {
      setState(() {
        _isLoading = widget.isMatricesLoading!;
      });
    }
  }

  Future<void> _initApi() async {
    final token = await _authService.getToken();
    _api = HangoApi(baseUrl: apiBaseUrl, token: token);
    _fetchMatrices();
  }

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _durationController = TextEditingController();
  final _passingScoreController = TextEditingController();

  Future<void> _fetchMatrices() async {
    try {
      final data = widget.isCourseManager
          ? await CourseManagerApi().getExamMatrices()
          : await _api.getExamMatrices();
      if (mounted) {
        setState(() {
          _matrices = data.where((m) => m['isPublic'] == true).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.show(context, 'System error, please try again later.', isError: true);
      }
    }
  }

  void _showMatrixDetails(Map<String, dynamic> matrix) {
    showDialog(
      context: context,
      builder: (context) {
        final List<dynamic> details = matrix['details'] ?? [];
        int currentQuestionIndex = 1;

        return AlertDialog(
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(matrix['title'] ?? 'Matrix Details', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text(matrix['description'] ?? 'No description provided.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.normal)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 650
                ? MediaQuery.of(context).size.width * 0.8
                : 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (details.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No detailed rules found.', style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                    )
                  else
                    ...details.map((d) {
                      final skill = d['skillParamName'] ?? 'Any Skill';
                      final difficulty = d['difficultyParamName'] ?? 'Any Difficulty';
                      final type = d['groupTypeName'] ?? 'Any Type';
                      final count = (d['quantity'] ?? 0) as int;
                      
                      final startIdx = currentQuestionIndex;
                      final endIdx = currentQuestionIndex + count - 1;
                      final questionLabel = count > 1 ? 'Questions $startIdx - $endIdx' : 'Question $startIdx';
                      
                      currentQuestionIndex += count;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    questionLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$count Item${count > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildDetailChip(Icons.psychology, skill, const Color(0xFFF0FDF4), const Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                _buildDetailChip(Icons.bar_chart, difficulty, const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
                                if (d['groupTypeId'] != null) ...[
                                  const SizedBox(width: 8),
                                  _buildDetailChip(Icons.category, type, const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color bgColor, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: iconColor.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Create Exam by Matrix',
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Exam Matrix',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'System will automatically pick questions based on the matrix rules.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 32),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('EXAM TITLE', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  hintText: 'Enter exam title...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 16),
                              const Text('EXAM DESCRIPTION', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Briefly describe what this exam covers...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('DURATION (MINS)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _durationController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: 'e.g. 60',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('PASSING SCORE', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _passingScoreController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: 'e.g. 5.0',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'EXAM MATRIX',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedMatrixId,
                                hint: const Text('Choose a matrix...'),
                                isExpanded: true,
                                selectedItemBuilder: (BuildContext context) {
                                  return _matrices.map<Widget>((e) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(e['title'] ?? 'Untitled', style: const TextStyle(fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList();
                                },
                                items: _matrices
                                    .map((e) => DropdownMenuItem(
                                          value: e['id'].toString(),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(child: Text(e['title'] ?? 'Untitled', style: const TextStyle(fontFamily: 'Outfit'))),
                                              IconButton(
                                                icon: const Icon(Icons.remove_red_eye, color: Color(0xFF38C9A6)),
                                                onPressed: () {
                                                  _showMatrixDetails(e);
                                                },
                                                tooltip: 'View Matrix Details',
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMatrixId = val);
                                  }
                                },
                              ),
                            ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedMatrixId == null
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    ToastHelper.show(context, 'Generating exam...');
                                    try {
                                      int examId;
                                      if (widget.isCourseManager) {
                                        examId = await CourseManagerApi().generateExamFromMatrix(
                                          int.parse(_selectedMatrixId!),
                                          _titleController.text.trim(),
                                          _descriptionController.text.trim(),
                                          int.tryParse(_durationController.text.trim()),
                                          null,
                                          double.tryParse(_passingScoreController.text.trim()),
                                        );
                                      } else {
                                        examId = await _api.generateExamFromMatrix(
                                          int.parse(_selectedMatrixId!),
                                          _titleController.text.trim(),
                                          _descriptionController.text.trim(),
                                          int.tryParse(_durationController.text.trim()),
                                          null,
                                          double.tryParse(_passingScoreController.text.trim()),
                                        );
                                      }
                                      if (mounted) {
                                        ToastHelper.show(context, 'Exam generated successfully!');
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CourseManagerEditExamPage(
                                              examId: examId,
                                              examTitle: _titleController.text.trim(),
                                              examExpectedCount: 0,
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ToastHelper.show(context, 'System error, please try again later.', isError: true);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF20B486),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Generate Exam',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
