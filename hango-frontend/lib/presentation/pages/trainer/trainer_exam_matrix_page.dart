import 'package:flutter/material.dart';
import 'trainer_edit_exam_page.dart';
import '../../../services/hango_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'package:flutter/foundation.dart';
import '../../../utils/config.dart';
class TrainerExamMatrixPage extends StatefulWidget {
  final VoidCallback onBack;
  const TrainerExamMatrixPage({super.key, required this.onBack});

  @override
  State<TrainerExamMatrixPage> createState() => _TrainerExamMatrixPageState();
}

class _TrainerExamMatrixPageState extends State<TrainerExamMatrixPage> {
  final _authService = AuthService();
  late HangoApi _api;
  List<Map<String, dynamic>> _matrices = [];
  bool _isLoading = true;
  String? _selectedMatrixId;

  String get apiBaseUrl => EnvConfig.apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    final token = await _authService.getToken();
    _api = HangoApi(baseUrl: apiBaseUrl, token: token);
    _fetchMatrices();
  }

  Future<void> _fetchMatrices() async {
    try {
      final data = await _api.getExamMatrices();
      if (mounted) {
        setState(() {
          _matrices = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.show(context, 'Failed to load matrices: $e', isError: true);
      }
    }
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
                const Text('Create Exam by Matrix',
                    style: TextStyle(
                        fontSize: 24,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 500,
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
                          items: _matrices
                              .map((e) => DropdownMenuItem(
                                    value: e['id'].toString(),
                                    child: Text(e['title'] ?? 'Untitled', style: const TextStyle(fontFamily: 'Outfit')),
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
                                ToastHelper.show(
                                    context, 'Generating exam...');
                                try {
                                  final examId = await _api.generateExamFromMatrix(
                                    int.parse(_selectedMatrixId!),
                                    null,
                                  );
                                  if (mounted) {
                                    ToastHelper.show(context, 'Exam generated successfully!');
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TrainerEditExamPage(
                                          examId: examId,
                                          examTitle: 'Generated Exam',
                                          examExpectedCount: 0,
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ToastHelper.show(context, 'Generation failed: $e', isError: true);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF20B486),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Generate Exam',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
