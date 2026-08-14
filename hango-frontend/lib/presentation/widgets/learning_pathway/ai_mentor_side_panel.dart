import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../utils/language_manager.dart';

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
  final ScrollController _scrollController = ScrollController();
  final PathwayRepository _repository = PathwayRepository();
  final List<Map<String, String>> _messages = [];
  final Set<String> _unlockAnnouncements = {};
  bool _isSending = false;
  bool _isRerouting = false;
  int? _conversationId;
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  List<String> _dynamicSuggestedQuestions = [];

  @override
  void initState() {
    super.initState();
    if (widget.pathway.mentorSummary.trim().isNotEmpty) {
      _messages.add({
        'role': 'mentor',
        'content': widget.pathway.mentorSummary,
      });
    }
    _syncCourseUnlockMessage();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _repository.getChatHistory(
        pathwayId: widget.pathway.pathwayId,
      );
      if (history.isNotEmpty && mounted) {
        setState(() {
          // Clear initial summary if we have real history to avoid duplicates
          if (_messages.isNotEmpty &&
              _messages.first['content'] == widget.pathway.mentorSummary) {
            _messages.clear();
          }

          for (var item in history.reversed) {
            if (item['reply'] != null) {
              final rawRole = item['role'] as String?;
              final role = (rawRole == 'USER') ? 'user' : 'mentor';
              _messages.add({
                'role': role,
                'content': item['reply'] as String,
              });
              if (_conversationId == null && item['conversation_id'] != null) {
                _conversationId = item['conversation_id'] as int;
              }
            }
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Could not load history: $e');
    }
  }

  Future<void> _clearChatHistory() async {
    final isVi = LanguageManager.isVi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isVi ? 'Xóa lịch sử chat?' : 'Clear Chat History?'),
        content: Text(isVi ? 'Toàn bộ lịch sử trò chuyện với AI Mentor sẽ bị xóa. Bạn có chắc chắn không?' : 'All conversation history with AI Mentor will be cleared. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isVi ? 'Xóa' : 'Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    try {
      await _repository.clearChatHistory(pathwayId: widget.pathway.pathwayId);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _conversationId = null;
        if (widget.pathway.mentorSummary.trim().isNotEmpty) {
          _messages.add({
            'role': 'mentor',
            'content': widget.pathway.mentorSummary,
          });
        }
        _dynamicSuggestedQuestions.clear();
      });
    } catch (e) {
      if (!mounted) return;
      final isVi = LanguageManager.isVi;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Không thể xóa lịch sử chat: $e' : 'Cannot clear chat history: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void didUpdateWidget(AIMentorSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pathway != oldWidget.pathway) {
      _syncCourseUnlockMessage();
    }
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
    _scrollController.dispose();
    _chatController.dispose();
    _chatFocusNode.dispose();
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

  void _syncCourseUnlockMessage() {
    final nodes = widget.pathway.nodes;
    for (var i = 0; i < nodes.length - 1; i++) {
      final completedNode = nodes[i];
      final nextNode = nodes[i + 1];
      final isNextUnlocked = nextNode.status == NodeStatus.inProgress;

      if (completedNode.status != NodeStatus.completed || !isNextUnlocked) {
        continue;
      }

      final key = '${completedNode.courseId}:${nextNode.courseId}';
      if (_unlockAnnouncements.contains(key)) continue;
      _unlockAnnouncements.add(key);

      _messages.add({
        'role': 'mentor',
        'content':
            '**${completedNode.courseTitle}** is completed. I have unlocked **${nextNode.courseTitle}** so you can keep the momentum going.',
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty || _isSending) return;

    final userMsg = message.trim();
    _chatController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMsg});
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final response = await _repository.sendChatMessage(
        pathwayId: widget.pathway.pathwayId,
        message: userMsg,
        conversationId: _conversationId,
        selectedNodeCourseId: widget.selectedNode?.courseId,
      );

      if (!mounted) return;

      setState(() {
        _conversationId = response['conversation_id'] as int?;
        _messages.add({
          'role': 'mentor',
          'content':
              response['reply'] as String? ??
              'Xin lỗi, tôi không thể trả lời lúc này.',
        });

        final List<dynamic>? newSuggestions = response['suggested_questions'];
        if (newSuggestions != null && newSuggestions.isNotEmpty) {
          _dynamicSuggestedQuestions = newSuggestions.cast<String>();
        } else {
          _dynamicSuggestedQuestions.clear();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('=== AI MENTOR CHAT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content': 'Connection error: $e',
        });
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
      _chatFocusNode.requestFocus();
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
      final hasSuggestion = updatedPathway.pendingRerouteSuggestion != null;
      setState(() {
        _messages.add({
          'role': 'mentor',
          'content': hasSuggestion
              ? 'I found an adjustment suggestion using your latest exam signal and current lesson progress. Review it below before applying.'
              : 'I checked your latest exam signal and current lesson progress. Your pathway still looks suitable, so no adjustment is needed right now.',
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
          IconButton(
            onPressed: () => _clearChatHistory(),
            icon: Icon(Icons.delete_sweep_rounded, color: dark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8), size: 20),
            tooltip: LanguageManager.isVi ? 'Xóa lịch sử chat' : 'Clear chat history',
            style: IconButton.styleFrom(
              hoverColor: Colors.red.withOpacity(0.1),
              highlightColor: Colors.red.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(bool dark) {
    // Only show action hub if there are dynamic suggestions OR we have a welcome summary but no history yet
    final showActionHub =
        _dynamicSuggestedQuestions.isNotEmpty || (_messages.length <= 1);
    final hasPendingReroute = widget.pathway.pendingRerouteSuggestion != null;
    final totalItems =
        _messages.length +
        (_isSending ? 1 : 0) +
        (hasPendingReroute ? 1 : 0) +
        (showActionHub ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index < _messages.length) {
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
        } else if (_isSending && index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF21262D) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(
                        color: dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        LanguageManager.isVi ? 'Đang phân tích...' : 'Analyzing...',
                        style: TextStyle(
                          color: dark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (hasPendingReroute && index == _messages.length + (_isSending ? 1 : 0)) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildRerouteActionArea(dark),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildActionHub(dark),
          );
        }
      },
    );
  }

  Widget _buildRerouteActionArea(bool dark) {
    final suggestion = widget.pathway.pendingRerouteSuggestion;
    if (suggestion == null) return const SizedBox.shrink();

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
                      final updatedPathway = await _repository.acceptReroute(
                        pathwayId: widget.pathway.pathwayId,
                      );
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
                      final updatedPathway = await _repository.declineReroute(
                        pathwayId: widget.pathway.pathwayId,
                      );
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

  Widget _buildActionHub(bool dark) {
    // If we have dynamic questions, use them
    List<String> actions = _dynamicSuggestedQuestions;

    // If no dynamic questions (e.g. initial load), provide some contextual starters
    if (actions.isEmpty) {
      final status = widget.selectedNode?.status;
      if (status == NodeStatus.inProgress) {
        actions = [
          'Vì sao mình nên học phần này?',
          'Phần này mất khoảng bao lâu?',
          'Có thể cho mình xin lộ trình nhanh được không?',
        ];
      } else {
        actions = [
          'Tiến độ của mình đang ở mức nào?',
          'Bạn có lời khuyên gì cho mục tiêu của mình không?',
        ];
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gợi ý cho bạn',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions.map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _sendChatMessage(action),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: dark ? const Color(0xFFF0F6FC) : const Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput(bool dark) {
    final inputBg = dark ? const Color(0xFF0D1117) : Colors.white;
    final borderColor = dark
        ? const Color(0xFF30363D)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: inputBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF161B22) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                      style: TextStyle(
                        fontSize: 14,
                        color: dark
                            ? const Color(0xFFF0F6FC)
                            : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Hỏi AI Mentor về lộ trình...',
                        hintStyle: TextStyle(
                          color: dark
                              ? const Color(0xFF8B949E)
                              : const Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _isSending ? null : _sendChatMessage,
                    ),
                  ),
                  if (_isSending)
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    )
                  else
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _sendChatMessage(_chatController.text),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
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
