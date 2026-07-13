import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../pages/course/course_detail_page.dart';

class AIMentorSidePanel extends StatefulWidget {
  final LearningPathway pathway;
  final PathwayNode? selectedNode;
  final ValueChanged<LearningPathway>? onPathwayUpdated;
  final bool isDarkMode;

  const AIMentorSidePanel({
    super.key,
    required this.pathway,
    this.selectedNode,
    this.onPathwayUpdated,
    this.isDarkMode = false,
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
  bool _isRerouting = false;

  @override
  void initState() {
    super.initState();
    _messages.add({'role': 'mentor', 'content': widget.pathway.mentorSummary});
  }

  @override
  void didUpdateWidget(AIMentorSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedNode != null &&
        widget.selectedNode != oldWidget.selectedNode) {
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content':
              'About ${widget.selectedNode!.courseTitle}:\n\n${widget.selectedNode!.reasonWhy}',
        });
      });
      _scrollToBottom();
    }
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
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
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
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'mentor', 'content': response});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content':
              'AI Mentor is unavailable right now. Please try again later.',
        });
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  Future<void> _confirmReroute() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Adjust this pathway?'),
        content: const Text(
          'AI Mentor will use your latest exam result and real course progress to suggest a smoother route.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep current'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28B79B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRerouting = true);
    try {
      final updatedPathway = await _repository.suggestReroute(
        pathwayId: widget.pathway.pathwayId,
      );
      widget.onPathwayUpdated?.call(updatedPathway);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content':
              'I updated the recommendation using your latest exam signal and current lesson progress.',
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content':
              'I could not adjust the pathway right now. Please try again later.',
        });
      });
    } finally {
      if (mounted) setState(() => _isRerouting = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final surface = dark ? const Color(0xFF161B22) : Colors.white;
    final border = dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(left: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.24 : 0.04),
            blurRadius: 18,
            offset: const Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(dark),
          Divider(height: 1, color: border),
          Expanded(child: _buildChatList(dark)),
          if (widget.selectedNode != null &&
              widget.selectedNode!.status != NodeStatus.locked)
            _buildActionArea(dark),
          Divider(height: 1, color: border),
          _buildChatInput(dark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF1E293B), Color(0xFF111827)]
              : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF28B79B)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Mentor',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark
                        ? const Color(0xFFF0F6FC)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Online and pathway-aware',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
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

  Widget _buildChatList(bool dark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMentor = message['role'] == 'mentor';
        final bubbleColor = isMentor
            ? (dark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC))
            : const Color(0xFF28B79B);
        final textColor = isMentor
            ? (dark ? const Color(0xFFF0F6FC) : const Color(0xFF334155))
            : Colors.white;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: isMentor
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMentor ? 4 : 14),
                      bottomRight: Radius.circular(isMentor ? 14 : 4),
                    ),
                    border: isMentor
                        ? Border.all(
                            color: dark
                                ? const Color(0xFF30363D)
                                : const Color(0xFFE2E8F0),
                          )
                        : null,
                  ),
                  child: isMentor
                      ? MarkdownBody(
                          data: message['content'] ?? '',
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(
                                Theme.of(context),
                              ).copyWith(
                                p: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                                strong: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                code: const TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 13,
                                ),
                              ),
                        )
                      : Text(
                          message['content'] ?? '',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRerouteActionArea(bool dark) {
    final suggestion = widget.pathway.pendingRerouteSuggestion;
    if (suggestion == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isRerouting ? null : _confirmReroute,
          icon: _isRerouting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: const Text('Suggest adjustment'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            side: const BorderSide(color: Color(0xFF6366F1)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF111827) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pathway update suggestion',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFF0F6FC)
                      : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                suggestion.rerouteReason ?? 'No reason provided.',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFF8B949E)
                      : const Color(0xFF475569),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRerouting
                ? null
                : () async {
                    setState(() => _isRerouting = true);
                    try {
                      final updatedPathway = await _repository.acceptReroute(pathwayId: widget.pathway.pathwayId);
                      widget.onPathwayUpdated?.call(updatedPathway);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to accept: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _isRerouting = false);
                    }
                  },
            icon: _isRerouting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28B79B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isRerouting
                ? null
                : () async {
                    setState(() => _isRerouting = true);
                    try {
                      final updatedPathway = await _repository.declineReroute(pathwayId: widget.pathway.pathwayId);
                      widget.onPathwayUpdated?.call(updatedPathway);

                      setState(() {
                        _messages.add({
                          'role': 'mentor',
                          'content': 'Kept current route as requested.',
                        });
                      });
                      _scrollToBottom();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to decline: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _isRerouting = false);
                    }
                  },
            icon: const Icon(Icons.pause_circle_filled_rounded),
            label: const Text('Keep current'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFF64748B)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(bool dark) {
    // Deprecated: kept for backward compatibility.
    // FE-11 uses _buildRerouteActionArea.

    return Container(
      padding: const EdgeInsets.all(14),
      color: dark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final node = widget.selectedNode;
                if (node == null || node.courseId <= 0) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailPage(courseId: node.courseId),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Start learning'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildRerouteActionArea(dark),
        ],
      ),
    );
  }

  Widget _buildChatInput(bool dark) {
    final inputBg = dark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
    return Container(
      padding: const EdgeInsets.all(12),
      color: dark ? const Color(0xFF161B22) : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _chatController,
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFF0F6FC)
                      : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Ask AI Mentor about this pathway...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: dark
                        ? const Color(0xFF8B949E)
                        : const Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _isSending
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF28B79B),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
