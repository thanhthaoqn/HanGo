import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../utils/toast_helper.dart';
import '../../../services/hango_api.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/config.dart';

class TrainerExamImportExcelPage extends StatefulWidget {
  final VoidCallback onBack;
  const TrainerExamImportExcelPage({super.key, required this.onBack});

  @override
  State<TrainerExamImportExcelPage> createState() =>
      _TrainerExamImportExcelPageState();
}

class _TrainerExamImportExcelPageState
    extends State<TrainerExamImportExcelPage> {
  bool _isLoading = false;
  bool _agreedToTerms = false;

  Future<HangoApi> _getApi() async {
    final token = await AuthService().getToken();
    return HangoApi(baseUrl: EnvConfig.apiBaseUrl, token: token);
  }

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final api = await _getApi();
      final bytes = await api.downloadExamTemplate();
      downloadBytes(
        bytes: bytes,
        filename: 'Hango_Exam_Import_Template.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) ToastHelper.show(context, 'Downloaded template!');
    } catch (e) {
      if (mounted) {
        ToastHelper.show(
          context,
          'Failed to download template: $e',
          isError: true,
        );
      }
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
        if (mounted)
          ToastHelper.show(context, 'Cannot read file bytes.', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      final api = await _getApi();
      // Import Excel directly (creates exams and questions)
      final response = await api.importExamExcel(
        pickedFile.bytes!,
        pickedFile.name,
      );

      final int examsCreated = response['totalExamsCreated'] as int? ?? 0;
      final int questionsImported = response['totalQuestionsImported'] as int? ?? 0;
      
      if (mounted) {
        ToastHelper.show(context, 'Successfully imported $examsCreated exams and $questionsImported questions!');
        Navigator.pop(context); // Go back to Exam List page
      }
    } catch (e) {
      if (mounted)
        ToastHelper.show(context, 'Import failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Import Exam Guidelines',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'Please download the template below and strictly follow these rules:',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Outfit',
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                _buildSectionTitle('1. Important Rules:'),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRuleItem('Each row', 'is a record.'),
                      _buildRuleItem(
                        'Exam Code',
                        'is the same between EXAM/QUESTIONS.',
                      ),
                      _buildRuleItem(
                        'Question Count',
                        'must be greater than 2 and less than or equal to 100.',
                      ),
                      _buildRuleItem(
                        'Passing Score',
                        'must be greater than 0 and less than or equal to 10.',
                      ),
                      _buildRuleItem(
                        'Time',
                        'must be greater than 0 (in minutes).',
                      ),
                      _buildRuleItem(
                        'Order Index',
                        'must be greater than 0, and the order of questions must not be duplicated.',
                      ),
                      _buildRuleItem(
                        'Passage Text',
                        '(optional): contains the content of the paragraph in the multiple question.',
                      ),
                      _buildRuleItem(
                        'Correct Answer',
                        'must be one of the selected options.',
                      ),
                      _buildRuleItem(
                        'Difficulty',
                        'includes: Easy, Medium, Hard, Very Hard.',
                      ),

                      const SizedBox(height: 16),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Skill Type Options (Click to view)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF20B486),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                bottom: 8.0,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    [
                                          'Phonetics',
                                          'Word order',
                                          'Reduced relative clause',
                                          'Preposition',
                                          'Collocation',
                                          'To-infinitive',
                                          'Quantifier',
                                          'Phrasal verb',
                                          'Prepositional phrase',
                                          'Vocabulary',
                                          'Conversation ordering',
                                          'Letter ordering',
                                          'Paragraph ordering',
                                          'Passive voice',
                                          'Relative clause',
                                          'Contextual meaning',
                                          'Factual / Detail question',
                                          'Synonym in context',
                                          'Antonym in context',
                                          'Reference question',
                                          'Paraphrasing question',
                                          'Paragraph-specific information question',
                                          'Main idea / Central theme question',
                                          'TRUE / NOT TRUE question',
                                          'Inference question',
                                        ]
                                        .map(
                                          (skill) => Chip(
                                            label: Text(
                                              skill,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'Outfit',
                                              ),
                                            ),
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            'Group Type Options (Click to view)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF20B486),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                bottom: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    [
                                          'Read and Fill in a Notice',
                                          'Read and Fill in a Leaflet/Advertisement',
                                          'Paragraph/Text Reordering',
                                          'Guided Cloze Test',
                                          'Reading Comprehension - 8 questions',
                                          'Reading Comprehension - 10 questions',
                                        ]
                                        .map(
                                          (type) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6.0,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.arrow_right,
                                                  size: 16,
                                                  color: Color(0xFF64748B),
                                                ),
                                                Text(
                                                  type,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontFamily: 'Outfit',
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('2. Upload File'),
                const Text(
                  'After filling in the information, upload this file to the system. The system will automatically generate the entire course structure.',
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Outfit',
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      activeColor: const Color(0xFF20B486),
                      onChanged: (val) {
                        setState(() {
                          _agreedToTerms = val ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'I agree with the above requirements',
                        style: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF20B486)),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _handleDownloadTemplate,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download Template'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E293B),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          disabledBackgroundColor: const Color(0xFFF1F5F9),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(width: 24),
                      ElevatedButton.icon(
                        onPressed: _agreedToTerms ? _handleImportExcel : null,
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Import Excel'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF20B486),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBackgroundColor: const Color(0xFF94A3B8),
                          disabledForegroundColor: Colors.white70,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }



  Widget _buildRuleItem(String boldText, String regularText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(Icons.check_circle, size: 16, color: Color(0xFF20B486)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Outfit',
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$boldText ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextSpan(text: regularText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
