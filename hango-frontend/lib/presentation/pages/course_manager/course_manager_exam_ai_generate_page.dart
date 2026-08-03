import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'course_manager_edit_exam_page.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/config.dart';
import '../../../data/repositories/trainer_ai_recommendation_repository.dart';
import '../../../domain/model/trainer_ai_exam_models.dart';
import '../../../domain/model/trainer_ai_question_models.dart';

class CourseManagerExamAiGeneratePage extends StatefulWidget {
  final VoidCallback onBack;
  final bool isCourseManager;
  const CourseManagerExamAiGeneratePage({super.key, required this.onBack, this.isCourseManager = true});

  @override
  State<CourseManagerExamAiGeneratePage> createState() =>
      _CourseManagerExamAiGeneratePageState();
}

class _CourseManagerExamAiGeneratePageState extends State<CourseManagerExamAiGeneratePage> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final TrainerAiQuestionRepository _repository = TrainerAiQuestionRepository();
  
  List<TrainerExamChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _messages.add(TrainerExamChatMessage(
      role: 'model',
      text: 'Hi there! I am your AI Assistant. I can help you generate a complete exam. To get started, please tell me the **Exam Title**, **Description**, **Duration**, **Passing Score**, and the **number and types of questions** you want (e.g. 10 easy vocabulary single questions, 1 medium reading comprehension group).',
    ));
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(TrainerExamChatMessage(role: 'user', text: text));
      _isLoading = true;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      final responseText = await _repository.chatExam(_messages);
      if (mounted) {
        setState(() {
          _messages.add(TrainerExamChatMessage(role: 'model', text: responseText));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Failed to get AI response: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateExam() async {
    setState(() => _isGenerating = true);
    ToastHelper.show(context, 'AI is generating exam based on our chat. This may take a minute...');
    try {
      final response = await _repository.generateExamFromChat(_messages);
      
      // Create the exam in the DB
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception('No token found');

      final apiBaseUrl = EnvConfig.v1BaseUrl;
      final payload = {
        'title': response.title,
        'description': response.description,
        'expectedQuestionCount': response.expectedQuestionCount,
        'passingScore': response.passingScore,
        'durationMinutes': response.durationMinutes,
        'thumbnailUrl': '',
      };

      final createResp = await http.post(
        Uri.parse('$apiBaseUrl/trainer/exams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (createResp.statusCode != 200 && createResp.statusCode != 201) {
        throw Exception('Failed to create exam: ${createResp.statusCode} - ${createResp.body}');
      }
      
      final createData = jsonDecode(createResp.body);
      final newExamId = createData['id'] as int;

      if (mounted) {
        ToastHelper.show(context, 'Exam created successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CourseManagerEditExamPage(
              examId: newExamId,
              examTitle: response.title,
              examExpectedCount: response.expectedQuestionCount,
              isCourseManager: widget.isCourseManager,
              initialAiData: response,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Failed to generate exam: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateExam,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  label: Text(
                    _isGenerating ? 'Generating...' : 'Generate Exam',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg.role == 'user';
                          return _buildChatMessage(msg, isUser);
                        },
                      ),
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: InputDecoration(
                                hintText: 'Type your requirements here...',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF8B5CF6),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildChatMessage(TrainerExamChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: Color(0xFFEDE9FE),
              child: Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF8B5CF6) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                  bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                ),
              ),
              child: MarkdownBody(
                data: msg.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : const Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            const CircleAvatar(
              backgroundColor: Color(0xFFE2E8F0),
              child: Icon(Icons.person, color: Color(0xFF64748B), size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
