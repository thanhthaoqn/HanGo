import 'package:flutter/material.dart';
import 'trainer_edit_exam_page.dart';
import '../../../utils/toast_helper.dart';

class TrainerExamMatrixPage extends StatefulWidget {
  final VoidCallback onBack;
  const TrainerExamMatrixPage({super.key, required this.onBack});

  @override
  State<TrainerExamMatrixPage> createState() => _TrainerExamMatrixPageState();
}

class _TrainerExamMatrixPageState extends State<TrainerExamMatrixPage> {
  String? _selectedMatrix;

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
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMatrix,
                          hint: const Text('Choose a matrix...'),
                          isExpanded: true,
                          items: ['Matrix 1 (TOEIC)', 'Matrix 2 (IELTS)']
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e, style: const TextStyle(fontFamily: 'Outfit')),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedMatrix = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedMatrix == null
                            ? null
                            : () {
                                ToastHelper.show(
                                    context, 'Generating based on $_selectedMatrix...');
                                Future.delayed(const Duration(milliseconds: 800), () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const TrainerEditExamPage(
                                        examId: 3, // Dummy ID
                                        examTitle: 'Matrix Exam',
                                      ),
                                    ),
                                  );
                                });
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
