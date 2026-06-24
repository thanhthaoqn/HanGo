import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hango/domain/model/ai_health.dart';
import 'package:hango/domain/model/ai_models.dart';
import 'package:hango/services/app_state.dart';
import 'package:hango/utils/app_theme.dart';

class LessonAiChatbox extends StatefulWidget {
  const LessonAiChatbox({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
  });

  final int lessonId;
  final String lessonTitle;

  @override
  State<LessonAiChatbox> createState() => _LessonAiChatboxState();
}

class _LessonAiChatboxState extends State<LessonAiChatbox> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  final List<AiMessage> _messages = [];
  Future<AiHealth>? _health;
  int? _conversationId;
  bool _open = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggle() {
    debugPrint(
      '[LessonAiChatbox] toggle pressed. lessonId=${widget.lessonId} open=${_open}',
    );
    setState(() {
      _open = !_open;
      _error = null;
      // Chỉ khi mở box VÀ _health chưa từng được gọi thì mới kích hoạt API status
      if (_open && _health == null) {
        _health = context.read<AppState>().checkAiStatus();
      }
    });
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AiMessage(role: 'USER', content: text));
      _message.clear();
    });
    _scrollToEnd();

    try {
      final response = await context.read<AppState>().sendAiMessage(
        lessonId: widget.lessonId,
        conversationId: _conversationId,
        message: text,
      );
      setState(() {
        _conversationId = response.conversationId;
        _messages.add(
          AiMessage(
            role: 'ASSISTANT',
            content: response.reply,
            wasOutOfScope: response.wasOutOfScope,
          ),
        );
      });
      _scrollToEnd();
    } catch (error) {
      setState(() {
        _error = error.toString();
        if (_messages.isNotEmpty && _messages.last.role == 'USER') {
          _messages.removeLast();
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width < 520 ? size.width - 32 : 420.0;
    final panelHeight = size.height < 680 ? size.height - 128 : 540.0;

    return Positioned(
      right: 18,
      bottom: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: _open ? 1 : .96,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _open
                  ? _ChatPanel(
                      key: const ValueKey('chat-panel'),
                      width: panelWidth,
                      height: panelHeight,
                      lessonTitle: widget.lessonTitle,
                      messages: _messages,
                      error: _error,
                      sending: _sending,
                      message: _message,
                      scroll: _scroll,
                      health:
                          _health ?? context.read<AppState>().checkAiStatus(),

                      onSend: _send,
                      onClose: _toggle,
                    )
                  : const SizedBox.shrink(key: ValueKey('closed-panel')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 62,
            height: 62,
            child: FloatingActionButton(
              heroTag: 'lesson-ai-${widget.lessonId}',
              shape: const CircleBorder(),
              tooltip: _open ? 'Đóng AI' : 'Mở AI',
              onPressed: _toggle,
              child: Icon(
                _open ? Icons.close_rounded : Icons.psychology_alt_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    super.key,
    required this.width,
    required this.height,
    required this.lessonTitle,
    required this.messages,
    required this.error,
    required this.sending,
    required this.message,
    required this.scroll,
    required this.health,
    required this.onSend,
    required this.onClose,
  });

  final double width;
  final double height;
  final String lessonTitle;
  final List<AiMessage> messages;
  final String? error;
  final bool sending;
  final TextEditingController message;
  final ScrollController scroll;
  final Future<AiHealth> health;
  final VoidCallback onSend;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.line)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.emerald,
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lessonTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        FutureBuilder<AiHealth>(
                          future: health,
                          builder: (context, snapshot) {
                            final available = snapshot.data?.available == true;
                            final waiting =
                                snapshot.connectionState ==
                                ConnectionState.waiting;
                            return Row(
                              children: [
                                Icon(
                                  waiting
                                      ? Icons.sync_rounded
                                      : available
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  size: 14,
                                  color: waiting
                                      ? AppTheme.muted
                                      : available
                                      ? AppTheme.emerald
                                      : const Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    waiting
                                        ? 'Đang kiểm tra Gemini'
                                        : snapshot.data?.message ??
                                              'Chưa kiểm tra AI',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Hỏi về bài học này để AI trả lời trong đúng ngữ cảnh.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _ChatBubble(message: messages[index]),
                    ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _InlineError(message: error!),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: message,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập câu hỏi trong bài học...',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Gửi',
                    onPressed: sending ? null : onSend,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == 'USER';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppTheme.emerald : const Color(0xFFEAF3EE),
          borderRadius: BorderRadius.circular(8),
          border: message.wasOutOfScope
              ? Border.all(color: const Color(0xFFE11D48))
              : null,
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: mine ? Colors.white : AppTheme.ink,
            height: 1.42,
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
