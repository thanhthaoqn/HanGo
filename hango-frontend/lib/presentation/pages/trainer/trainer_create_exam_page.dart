import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';
import 'trainer_exams_page.dart';

class TrainerCreateExamPage extends StatefulWidget {
  const TrainerCreateExamPage({super.key});

  @override
  State<TrainerCreateExamPage> createState() => _TrainerCreateExamPageState();
}

class _TrainerCreateExamPageState extends State<TrainerCreateExamPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _questionsController = TextEditingController();
  final _dateController = TextEditingController();
  final _passingScoreController = TextEditingController();
  final _durationController = TextEditingController();

  bool _isSubmitting = false;

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  @override
  void initState() {
    super.initState();
    // Initialize current date
    final now = DateTime.now();
    _dateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _questionsController.dispose();
    _dateController.dispose();
    _passingScoreController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'expectedQuestionCount': int.tryParse(_questionsController.text.trim()) ?? 0,
        'passingScore': double.tryParse(_passingScoreController.text.trim()) ?? 0.0,
        'durationMinutes': int.tryParse(_durationController.text.trim()) ?? 0,
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/trainer/exams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ToastHelper.show(context, 'Exam created successfully in DRAFT status');
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create exam: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.show(context, 'Error creating exam: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Exam > Create New Exam',
          style: TextStyle(
            color: Color(0xFF20B486),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New Exam',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildLabel('EXAM TITLE'),
                  _buildTextField(
                    controller: _titleController,
                    hintText: 'Đề thi THPTQG môn tiếng anh năm 2025',
                    validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('EXAM DESCRIPTION'),
                  _buildTextField(
                    controller: _descriptionController,
                    hintText: 'Briefly describe what this quiz covers...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('NUMBER OF QUESTION'),
                            _buildTextField(
                              controller: _questionsController,
                              hintText: '50',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('CREATE DATE'),
                            _buildTextField(
                              controller: _dateController,
                              readOnly: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('PASSING SCORE (%)'),
                            _buildTextField(
                              controller: _passingScoreController,
                              hintText: '70',
                              keyboardType: TextInputType.number,
                              suffixText: '%',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('TIME LIMIT (MINUTES)'),
                            _buildTextField(
                              controller: _durationController,
                              hintText: '60',
                              keyboardType: TextInputType.number,
                              suffixText: 'min',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF20B486),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Create Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 14,
        fontFamily: 'Outfit',
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      ),
    );
  }
}
