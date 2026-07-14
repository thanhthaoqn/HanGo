import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'trainer_edit_exam_page.dart';
import '../../../utils/toast_helper.dart';
import '../../../services/hango_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/download_helper.dart';

class TrainerExamImportExcelPage extends StatefulWidget {
  final VoidCallback onBack;
  const TrainerExamImportExcelPage({super.key, required this.onBack});

  @override
  State<TrainerExamImportExcelPage> createState() => _TrainerExamImportExcelPageState();
}

class _TrainerExamImportExcelPageState extends State<TrainerExamImportExcelPage> {
  bool _isLoading = false;

  Future<HangoApi> _getApi() async {
    final token = await AuthService().getToken();
    return HangoApi(
      baseUrl: 'http://localhost:8080',
      token: token,
    );
  }

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final api = await _getApi();
      final bytes = await api.downloadExamTemplate();
      downloadBytes(bytes, 'exam_template.xlsx');
      if (mounted) ToastHelper.show(context, 'Downloaded template!');
    } catch (e) {
      if (mounted) ToastHelper.show(context, 'Failed to download template: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImportExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      if (pickedFile.bytes == null) {
        if (mounted) ToastHelper.show(context, 'Cannot read file bytes.', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      final api = await _getApi();
      // 1. Create a draft exam
      final examId = await api.createDraftExam('Imported Exam');

      // 2. Import Excel into the new exam
      final response = await api.importExamExcel(
        examId,
        pickedFile.bytes!,
        pickedFile.name,
      );

      final int count = response['totalQuestions'] as int? ?? 0;
      if (mounted) {
        ToastHelper.show(context, 'Successfully imported $count questions!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrainerEditExamPage(
              examId: examId,
              examTitle: 'Imported Exam',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ToastHelper.show(context, 'Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  onPressed: _isLoading ? null : widget.onBack,
                ),
                const SizedBox(width: 8),
                const Text('Import Exam by Excel',
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
              child: _isLoading 
                ? const CircularProgressIndicator(color: Color(0xFF20B486))
                : Wrap(
                spacing: 32,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: [
                  InkWell(
                    onTap: _handleDownloadTemplate,
                    child: Container(
                      width: 250,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.download_rounded,
                              size: 48, color: Color(0xFF475569)),
                          SizedBox(height: 16),
                          Text('Download Template',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _handleImportExcel,
                    child: Container(
                      width: 250,
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B486), // Emerald
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.upload_file_rounded,
                              size: 48, color: Colors.white),
                          SizedBox(height: 16),
                          Text('Upload Excel File',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
