import 'package:flutter/material.dart';
import 'trainer_edit_exam_page.dart';
import '../../../utils/toast_helper.dart';

class TrainerExamAiGeneratePage extends StatefulWidget {
  final VoidCallback onBack;
  const TrainerExamAiGeneratePage({super.key, required this.onBack});

  @override
  State<TrainerExamAiGeneratePage> createState() =>
      _TrainerExamAiGeneratePageState();
}

class _TrainerExamAiGeneratePageState extends State<TrainerExamAiGeneratePage> {
  final _topicController = TextEditingController();
  final _countController = TextEditingController();
  String _selectedDifficulty = 'Medium';
  String? _selectedSkillType;
  String? _selectedGroupType;

  @override
  void dispose() {
    _topicController.dispose();
    _countController.dispose();
    super.dispose();
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
                const Text('Generate Exam with AI',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Exam Generation Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildLabel('TOPIC OR DOCUMENT CONTENT'),
                      TextField(
                        controller: _topicController,
                        maxLines: 4,
                        decoration: _inputDecoration('Enter the topic or paste context for AI...'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('NUMBER OF QUESTIONS'),
                                TextField(
                                  controller: _countController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('e.g., 20'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('DIFFICULTY'),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedDifficulty,
                                      isExpanded: true,
                                      items: ['Easy', 'Medium', 'Hard']
                                          .map((e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e, style: const TextStyle(fontFamily: 'Outfit')),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedDifficulty = val);
                                        }
                                      },
                                    ),
                                  ),
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
                                _buildLabel('SKILL TYPE (Optional)'),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSkillType,
                                      hint: const Text(
                                        'Select Skill Type',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      isExpanded: true,
                                      items: [
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
                                          .map((e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() => _selectedSkillType = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('GROUP TYPE (Optional)'),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedGroupType,
                                      hint: const Text(
                                        'Select Group Type',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      isExpanded: true,
                                      items: [
                                        'Read and Fill in a Notice',
                                        'Read and Fill in a Leaflet/Advertisement',
                                        'Paragraph/Text Reordering',
                                        'Guided Cloze Test',
                                        'Reading Comprehension - 8 questions',
                                        'Reading Comprehension - 10 questions'
                                      ]
                                          .map((e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13)),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() => _selectedGroupType = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ToastHelper.show(context, 'AI is generating exam...');
                            Future.delayed(const Duration(seconds: 1), () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TrainerEditExamPage(
                                    examId: 2, // Dummy ID
                                    examTitle: 'AI Generated Exam',
                                  ),
                                ),
                              );
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6), // AI Purple
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Generate Exam',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
      ),
    );
  }
}
