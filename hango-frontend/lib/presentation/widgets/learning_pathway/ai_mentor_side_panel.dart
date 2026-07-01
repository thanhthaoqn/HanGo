import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../pages/course/course_detail_page.dart';

class AIMentorSidePanel extends StatefulWidget {
  final LearningPathway pathway;
  final PathwayNode? selectedNode;
  final ValueChanged<LearningPathway>? onPathwayUpdated;

  const AIMentorSidePanel({
    super.key,
    required this.pathway,
    this.selectedNode,
    this.onPathwayUpdated,
  });

  @override
  State<AIMentorSidePanel> createState() => _AIMentorSidePanelState();
}

class _AIMentorSidePanelState extends State<AIMentorSidePanel> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PathwayRepository _repository = PathwayRepository();
  final List<Map<String, String>> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add({
      'role': 'mentor',
      'content': widget.pathway.mentorSummary,
    });
  }

  @override
  void didUpdateWidget(AIMentorSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNode != null && widget.selectedNode != oldWidget.selectedNode) {
      // Add a message explaining the selected node
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content': 'Về ${widget.selectedNode!.courseTitle}:\n\n${widget.selectedNode!.reasonWhy}',
        });
      });
      _scrollToBottom();
    }
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
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _chatController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await _repository.chatWithMentor(
        pathwayId: widget.pathway.pathwayId,
        message: text,
      );
      if (mounted) {
        setState(() {
          _messages.add({'role': 'mentor', 'content': response});
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'mentor',
            'content': 'Hiện chưa thể kết nối AI Mentor. Vui lòng thử lại sau.',
          });
          _isSending = false;
        });
      }
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          left: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _buildChatList(),
          ),
          if (widget.selectedNode != null && widget.selectedNode!.status != NodeStatus.locked)
            _buildActionArea(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(79, 70, 229, 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Mentor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Đang trực tuyến',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMentor = message['role'] == 'mentor';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: isMentor ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isMentor) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF4F46E5), size: 16),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMentor ? const Color(0xFFF8FAFC) : const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMentor ? 4 : 16),
                      bottomRight: Radius.circular(isMentor ? 16 : 4),
                    ),
                    border: isMentor ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                  ),
                  child: isMentor
                      ? MarkdownBody(
                          data: message['content'] ?? '',
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: const TextStyle(color: Color(0xFF334155), fontSize: 14, height: 1.5),
                            strong: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold),
                            code: const TextStyle(color: Color(0xFF4F46E5), fontSize: 13),
                          ),
                        )
                      : Text(
                          message['content'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
              if (!isMentor) const SizedBox(width: 40),
              if (isMentor) const SizedBox(width: 40),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildActionArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (widget.selectedNode != null && widget.selectedNode!.courseId > 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailPage(courseId: widget.selectedNode!.courseId),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Bắt đầu học ngay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final updatedPathway = await _repository.reroutePathway(
                    pathwayId: widget.pathway.pathwayId,
                    quizScore: 42,
                  );
                  widget.onPathwayUpdated?.call(updatedPathway);
                  if (mounted) {
                    setState(() {
                      _messages.add({
                        'role': 'mentor',
                        'content': 'Đã kích hoạt Dynamic Re-routing vì điểm quiz gần đây thấp. Lộ trình mới đã được cập nhật.',
                      });
                    });
                    _scrollToBottom();
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      _messages.add({
                        'role': 'mentor',
                        'content': 'Không thể tái lập lộ trình lúc này. Vui lòng thử lại sau.',
                      });
                    });
                    _scrollToBottom();
                  }
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tái lập lộ trình'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _chatController,
                decoration: const InputDecoration(
                  hintText: 'Hỏi AI Mentor về lộ trình...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isSending ? const Color(0xFF94A3B8) : const Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
